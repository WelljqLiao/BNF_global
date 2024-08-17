clc, clear all
cd("3_Model result\")
% colormap
mycolorpoint=[[253 231 36];...
    [91 200 98];
    [32 143 140];
    [28 82 139];
    [68 1 84]];

mycolorposition=[1 32 64 96 128];
mycolormap_r=interp1(mycolorposition,mycolorpoint(:,1),1:128,'linear','extrap');
mycolormap_g=interp1(mycolorposition,mycolorpoint(:,2),1:128,'linear','extrap');
mycolormap_b=interp1(mycolorposition,mycolorpoint(:,3),1:128,'linear','extrap');
mycolor=[mycolormap_r',mycolormap_g',mycolormap_b']/255;
mycolor=round(mycolor*10^4)/10^4;
%% size calculate
load FNF_predict
load Area_WGS_1984_720_360.mat  % unit m2
Area = Area_WGS_1984/10000; % unit ha

area_FNF = BNF_predict.*Area;  % unit kg/yr-1
total_BNF = sum(area_FNF,'all','omitnan');
total_BNF = total_BNF*1000*1e-12; % unit Tg
disp(['Global FNF amount = ',num2str(total_BNF)]);

FNF_STD = BNF_predict.*BNF_cv;
FNF_STD_area = FNF_STD.*Area;
FNF_STD_all = sum(FNF_STD_area,'all','omitnan');
FNF_STD_all = FNF_STD_all*1000*1e-12; 
disp(['Global FNF SD = ',num2str(FNF_STD_all)]);

% BNF_predict = flipud(BNF_predict);
% BNF_predict = imresize(BNF_predict,[1800,3600],'nearest');
% R = georefcells([-90 90], [-180 180], size(BNF_predict));
% 
% BNF_cv = flipud(BNF_cv);
% BNF_cv = imresize(BNF_cv,[1800,3600],'nearest');
% 
% % save GeoTIFF
% geotiffwrite('FNF_predict.tif', BNF_predict, R);
% geotiffwrite('FNF_uncer.tif', BNF_cv, R);

load SNF_predict.mat
area_SNF = BNF_predict.*Area;  
total_BNF = sum(area_SNF,'all','omitnan'); 
total_BNF = total_BNF*1000*1e-12; 
disp(['Global SNF amount = ',num2str(total_BNF)]);

SNF_STD = BNF_predict.*BNF_cv;
SNF_STD_area = SNF_STD.*Area;
SNF_STD_all = sum(SNF_STD_area,'all','omitnan'); 
SNF_STD_all = SNF_STD_all*1000*1e-12;
disp(['Global SNF SD = ',num2str(SNF_STD_all)]);

% SNF_predict = flipud(BNF_predict);
% SNF_predict = imresize(SNF_predict,[1800,3600],'nearest');
% R = georefcells([-90 90], [-180 180], size(SNF_predict));
% BNF_cv = flipud(BNF_cv);
% BNF_cv = imresize(BNF_cv,[1800,3600],'nearest');
% geotiffwrite('SNF_predict.tif', SNF_predict, R);
% geotiffwrite('SNF_uncer.tif', BNF_cv, R);


%% ecosystem statics
[Landcover_2020 R] = readgeoraster('Landcover_WGS84.tif');
Land = Landcover_2020;
Land = imresize(Land,[360,720],'nearest');

fracdata = {'area_SNF','area_FNF'};
for n = 1:17
    cover_idx = find(Land == n);
    for i = 1:2
        Eco_data = eval(fracdata{i});
        cover_map = Eco_data(cover_idx);
        cover_sum = sum(cover_map,"all",'omitnan');
        Ecomean(i,n) = cover_sum*1000*1e-12; 
    end
end
disp('全球求和')
sum(Ecomean,2,'omitnan')

colNames = {'ENF','EBF','DNF','DBF','MF','CS','OS',...
    'WSava','Sava','Grass','Perma','Crop','Urban','Crop&Vet','Snow','Barren','Unclass'};
EcoT = array2table(Ecomean, 'VariableNames', colNames,'RowNames', fracdata);
disp(EcoT)
%% pie
gsum = sum(Ecomean,1,'omitnan'); % bnf
% gsum = Ecomean(1,:); % snf
% gsum = Ecomean(2,:); % fnf

gsum(:,6) = gsum(:,6) + gsum(:,7);
gsum(:,7) = [];
gsum(:,10:16) = [];

Label = {'ENF','EBF','DNF','DBF','MIX','SHB','WAS','SAV','GRS'};
p = pie(gsum);
colormap(flipud(mycolor))
hLegend = legend(Label, 'Position', [0.87 0.2 0.1 0.3]);
hLegend.ItemTokenSize = [5 5];
legend('boxoff');
th = findobj(gca, 'Type', 'text');
set(th, 'FontName', 'Times', 'FontSize', 13)
set(hLegend, 'FontName',  'Times', 'FontSize', 11)
set(gcf,'Color',[1 1 1])

