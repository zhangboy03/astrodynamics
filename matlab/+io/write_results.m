function write_results(filename, data)
% WRITE_RESULTS Write results.txt in required format
%
% Format: 10 columns, space-separated
% Column order per assignment.md:
%   Event, Time, x, y, vx, vy, dvx, dvy, M_fuel, M_carry
%
% - Column 1 (Event): integer
% - Columns 2-10: scientific notation with 12 significant digits
%
% Inputs:
%   filename - output file path
%   data     - [N x 10] matrix with columns in the order above

    fid = fopen(filename, 'w');
    if fid == -1
        error('Cannot open file: %s', filename);
    end

    for i = 1:size(data, 1)
        % Format each value
        line_str = '';
        for j = 1:10
            if j == 1
                % Event is integer (column 1)
                val_str = sprintf('%d', round(data(i, j)));
            else
                % All other columns: scientific notation, 12 significant digits
                val_str = sprintf('%.12e', data(i, j));
            end

            if j < 10
                line_str = [line_str, val_str, ' '];
            else
                line_str = [line_str, val_str];
            end
        end
        fprintf(fid, '%s\n', line_str);
    end

    fclose(fid);
end
