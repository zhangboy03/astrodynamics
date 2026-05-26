classdef ResultsBuilder < handle
% RESULTSBUILDER Build and validate results.txt event sequences
%
% Maintains a state machine ensuring correct event ordering:
%   INIT -> DEPARTED(1) -> COASTING/BURNING -> ARRIVED_MOON(2) ->
%   LEFT_MOON(3) -> COASTING/BURNING -> RETURNED(4)
%
% Usage:
%   rb = io.ResultsBuilder();
%   rb.add_departure(t, X, dv, M_fuel, M_carry);
%   rb.add_coast(t_vec, X_mat, M_fuel, M_carry);
%   rb.add_burn(t, X, dv, M_fuel_before, M_fuel_after, M_carry);
%   rb.add_arrive_moon(t, X, M_fuel, M_carry);
%   rb.add_leave_moon(t, X, M_fuel);
%   rb.add_return_earth(t, X, M_fuel);
%   rb.validate();
%   rb.write('results.txt');

    properties
        data        % [N x 10] accumulated rows
        state       % current state machine state
        n_rows      % number of rows added
    end

    methods
        function obj = ResultsBuilder()
            obj.data = [];
            obj.state = 'INIT';
            obj.n_rows = 0;
        end

        function add_departure(obj, t, X, dv, M_fuel, M_carry)
            % Event=1: Departure from LEO
            % Two rows: first with dv=0, second with actual dv
            % Fuel is NOT consumed (launch vehicle provides dv)
            assert(strcmp(obj.state, 'INIT'), 'Departure must be first event');

            % Row 1: before burn (dv=0)
            obj.add_row(t, X, [0;0], M_fuel, M_carry, 1);
            % Row 2: after burn (dv applied, fuel unchanged)
            X_after = X(:);
            X_after(3:4) = X_after(3:4) + dv(:);
            obj.add_row(t, X_after, dv, M_fuel, M_carry, 1);

            obj.state = 'DEPARTED';
        end

        function add_coast(obj, t_vec, X_mat, M_fuel, M_carry)
            % Event=0: Free coasting segment
            % At least 2 rows (start + end states)
            assert(~strcmp(obj.state, 'INIT'), 'Cannot coast before departure');
            assert(~strcmp(obj.state, 'RETURNED'), 'Cannot coast after return');

            n = length(t_vec);
            assert(n >= 2, 'Coast must have at least 2 points');

            for i = 1:n
                obj.add_row(t_vec(i), X_mat(i,:)', [0;0], M_fuel, M_carry, 0);
            end
        end

        function add_burn(obj, t, X_before, dv, M_fuel_before, M_fuel_after, M_carry)
            % Event=-1: Spacecraft maneuver (consumes fuel)
            % Two rows: before and after
            assert(~strcmp(obj.state, 'INIT'), 'Cannot burn before departure');
            assert(~strcmp(obj.state, 'RETURNED'), 'Cannot burn after return');

            % Row 1: before burn (dv=0)
            obj.add_row(t, X_before, [0;0], M_fuel_before, M_carry, -1);
            % Row 2: after burn
            X_after = X_before(:);
            X_after(3:4) = X_after(3:4) + dv(:);
            obj.add_row(t, X_after, dv, M_fuel_after, M_carry, -1);

            obj.state = 'BURNING';
        end

        function add_dock(obj, t, X, M_fuel_before, M_fuel_after, M_carry)
            % Event=5: Docking with supply spacecraft
            % Two rows if fuel changes, one row if no change
            assert(~strcmp(obj.state, 'INIT'), 'Cannot dock before departure');

            % Row 1: before docking
            obj.add_row(t, X, [0;0], M_fuel_before, M_carry, 5);
            if abs(M_fuel_after - M_fuel_before) > 0.01
                % Row 2: after fuel change
                obj.add_row(t, X, [0;0], M_fuel_after, M_carry, 5);
            end
        end

        function add_arrive_moon(obj, t, X, M_fuel, M_carry)
            % Event=2: Arrive at Moon
            % M_carry becomes 0 (payload left on Moon)
            assert(~strcmp(obj.state, 'INIT'), 'Cannot arrive before departure');

            obj.add_row(t, X, [0;0], M_fuel, 0, 2);
            obj.state = 'AT_MOON';
        end

        function add_leave_moon(obj, t, X, M_fuel)
            % Event=3: Leave Moon
            % Must immediately follow Event=2
            % M_carry = 0
            assert(strcmp(obj.state, 'AT_MOON'), 'Must arrive at Moon before leaving');

            obj.add_row(t, X, [0;0], M_fuel, 0, 3);
            obj.state = 'LEFT_MOON';
        end

        function add_return_earth(obj, t, X, M_fuel)
            % Event=4: Return to Earth
            % Must be last row, dv=0, perigee=0km, fuel<=100kg
            assert(~strcmp(obj.state, 'INIT'), 'Cannot return before departure');

            obj.add_row(t, X, [0;0], M_fuel, 0, 4);
            obj.state = 'RETURNED';
        end

        function valid = validate(obj)
            % Validate the complete event sequence
            % Column order: Event(1), Time(2), x(3), y(4), vx(5), vy(6),
            %               dvx(7), dvy(8), M_fuel(9), M_carry(10)
            valid = true;
            errors = {};

            if obj.n_rows == 0
                errors{end+1} = 'No data rows';
                valid = false;
            end

            % Check first event is departure (1)
            if obj.data(1, 1) ~= 1
                errors{end+1} = 'First event must be departure (1)';
                valid = false;
            end

            % Check last event is return (4)
            if obj.data(end, 1) ~= 4
                errors{end+1} = 'Last event must be return (4)';
                valid = false;
            end

            % Check Event 2 and 3 are adjacent
            idx2 = find(obj.data(:,1) == 2);
            idx3 = find(obj.data(:,1) == 3);
            if ~isempty(idx2) && ~isempty(idx3)
                if idx3(1) ~= idx2(end) + 1
                    errors{end+1} = 'Event 3 must immediately follow Event 2';
                    valid = false;
                end
            end

            % Check time is non-decreasing (column 2)
            if any(diff(obj.data(:,2)) < -1e-10)
                errors{end+1} = 'Time must be non-decreasing';
                valid = false;
            end

            % Check return fuel <= 100 kg (column 9)
            if obj.data(end, 9) > 100
                errors{end+1} = sprintf('Return fuel %.1f > 100 kg', obj.data(end,9));
                valid = false;
            end

            % Check fuel consistency for burns (Event=-1)
            burn_idx = find(obj.data(:,1) == -1);
            for i = 1:2:length(burn_idx)
                if i+1 <= length(burn_idx)
                    % dv is in columns 7:8
                    dv_vu = norm(obj.data(burn_idx(i+1), 7:8));
                    if dv_vu > 0
                        p = const.params();
                        dv_mps = units.dv_vu2mps(dv_vu, p);
                        % M_fuel is column 9, M_carry is column 10
                        M_before = obj.data(burn_idx(i), 9) + obj.data(burn_idx(i), 10) + p.m_dry;
                        M_expected = M_before * exp(-dv_mps / p.ve);
                        M_fuel_expected = obj.data(burn_idx(i), 9) - (M_before - M_expected);
                        if abs(obj.data(burn_idx(i+1), 9) - M_fuel_expected) > 1
                            errors{end+1} = sprintf('Fuel inconsistency at row %d', burn_idx(i+1));
                            valid = false;
                        end
                    end
                end
            end

            if ~valid
                fprintf('Validation errors:\n');
                for i = 1:length(errors)
                    fprintf('  - %s\n', errors{i});
                end
            end
        end

        function write(obj, filename)
            % Write results to file
            assert(obj.validate(), 'Validation failed, cannot write');
            io.write_results(filename, obj.data);
            fprintf('Results written to %s (%d rows)\n', filename, obj.n_rows);
        end
    end

    methods (Access = private)
        function add_row(obj, t, X, dv, M_fuel, M_carry, event)
            % Column order per assignment.md:
            % Event, Time, x, y, vx, vy, dvx, dvy, M_fuel, M_carry
            row = [event, t, X(1), X(2), X(3), X(4), dv(1), dv(2), M_fuel, M_carry];
            obj.data = [obj.data; row];
            obj.n_rows = obj.n_rows + 1;
        end
    end
end
