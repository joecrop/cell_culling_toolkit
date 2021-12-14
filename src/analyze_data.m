%% these measurements are used in the method!

%[cell, a, b, tphl, c] = textread('./reports/tphl_delay_monte_sim_0.4.txt', '%s %f %f %f %s', 'headerlines', 1, 'delimiter', '\t');
%[cell, a, b, tplh, c] = textread('./reports/tplh_delay_monte_sim_0.4.txt', '%s %f %f %f %s', 'headerlines', 1, 'delimiter', '\t');

%for i = 1:length(tphl)
%    if(tphl(i) == 0 || tplh(i) == 0)
%        avg(i,1) = 0;
%    else
%        avg(i,1) = (tphl(i)+tplh(i))/2;
%    end
%end

min = (mean(avg)-(2*std(avg)));
min = (mean(avg)-min)/3+min
max = (mean(avg)+(2*std(avg)));
max = max-(max-mean(avg))/3

j=0;k=0;
for i=1:length(avg)
   if(avg(i) > max)
       j=j+1;
      bad_cells(j,1) = cell(i); 
      bad_cell_timing(j,1) = avg(i);
   elseif(avg(i) < min)
       j=j+1;
       bad_cells(j,1) = cell(i);
       bad_cell_timing(j,1) = avg(i);
   else
       k=k+1;
       good_cells(k,1) = cell(i);
       good_cell_timing(k,1) = avg(i);
   end
end

figure
%hist(avg,40);
%hold on
hist(good_cell_timing,40)

bad_cells
bad_cell_timing
