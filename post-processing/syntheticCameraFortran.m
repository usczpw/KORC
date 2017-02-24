function ST = syntheticCameraFortran(path,lambdas,visible,range)
close all

ST = struct;
ST.path = path;
ST.visible = visible;
ST.lambdas = lambdas;

ST.range = range;
ST.num_snapshots = ST.range(2) - ST.range(1) + 1;

ST.params = loadSimulationParameters(ST);

ST.time = ...
    ST.params.simulation.dt*double(ST.params.simulation.output_cadence)*double(ST.range(1):1:ST.range(2));

ST.data = loadData(ST);

% plotSyntheticCameraAnalysis(ST)

generateFigures(ST)

end

function params = loadSimulationParameters(ST)
params = struct;

info = h5info([ST.path 'simulation_parameters.h5']);

for ii=1:length(info.Groups)
    for jj=1:length(info.Groups(ii).Datasets)
        name = info.Groups(ii).Name(2:end);
        subname = info.Groups(ii).Datasets(jj).Name;
        params.(name).(subname) = ...
            h5read(info.Filename,['/' name '/' subname]);
    end
end

info = h5info([ST.path 'synthetic_camera.h5']);

for ii=1:length(info.Groups)
    for jj=1:length(info.Groups(ii).Datasets)
        name = info.Groups(ii).Name(2:end);
        subname = info.Groups(ii).Datasets(jj).Name;
        params.(name).(subname) = ...
            h5read(info.Filename,['/' name '/' subname]);
    end
end
end

function data = loadData(ST)
data = struct;

list = {'Psyn_pixel','np_pixel','Psyn_pplane','np_pplane'};

it = ST.range(1):1:ST.range(2);

NX = ST.params.synthetic_camera_params.num_pixels(1);
NY = ST.params.synthetic_camera_params.num_pixels(2);
Nl = ST.params.synthetic_camera_params.Nlambda;

for ll=1:length(list)
    disp(['Loading ' list{ll}])
    for ss=1:ST.params.simulation.num_species
        data.(['sp' num2str(ss)]).(list{ll}) = zeros(NX,NY,Nl,ST.num_snapshots);
        filename = [ST.path 'synthetic_camera_snapshots.h5'];
        for ii=1:numel(it)
            dataset = ...
                ['/' num2str(it(ii)*double(ST.params.simulation.output_cadence)) '/spp_' num2str(ss)...
                '/' list{ll}];
            data.(['sp' num2str(ss)]).(list{ll})(:,:,:,ii) = h5read(filename, dataset);
        end
    end
end

list={'PTot_pplane'};

for ll=1:length(list)
    disp(['Loading ' list{ll}])
    for ss=1:ST.params.simulation.num_species
        data.(['sp' num2str(ss)]).(list{ll}) = zeros(NX,NY,ST.num_snapshots);
        filename = [ST.path 'synthetic_camera_snapshots.h5'];
        for ii=1:numel(it)
            dataset = ...
                ['/' num2str(it(ii)*double(ST.params.simulation.output_cadence)) '/spp_' num2str(ss)...
                '/' list{ll}];
            data.(['sp' num2str(ss)]).(list{ll})(:,:,ii) = h5read(filename, dataset);
        end
    end
end

end

function plotSyntheticCameraAnalysis(ST)
disp('Plotting snapshots...')

lambda = ST.params.synthetic_camera_params.lambda;
xAxis = ST.params.synthetic_camera_params.pixels_nodes_x;
yAxis = ST.params.synthetic_camera_params.pixels_nodes_y;

NX = ST.params.synthetic_camera_params.num_pixels(1);
NY = ST.params.synthetic_camera_params.num_pixels(2);

RAxis = ST.params.poloidal_plane_params.nodes_R;
ZAxis = ST.params.poloidal_plane_params.nodes_Z;
NR = ST.params.poloidal_plane_params.grid_dims(1);
NZ = ST.params.poloidal_plane_params.grid_dims(1);

[~,i1] = min(abs(lambda - ST.lambdas(1)));
[~,i2] = min(abs(lambda - ST.lambdas(2)));
Nl = i2 - i1 + 1;

for ss=1:ST.params.simulation.num_species
    disp(['Species: ' num2str(ss)])
    Psyn_lambda_pixel = zeros(NX,NY,Nl);
    np_lambda_pixel = zeros(NX,NY,Nl);
    Psyn_pixel = zeros(NX,NY);
    np_pixel = zeros(NX,NY);
    
    Psyn_lambda_pplane = zeros(NX,NY,Nl);
    np_lambda_pplane = zeros(NX,NY,Nl);
    Psyn_pplane = zeros(NX,NY);
    np_pplane = zeros(NX,NY);
    
    for ii=1:NX
        for jj=1:NY
            Psyn_lambda_pixel(ii,jj,:) = sum(ST.data.(['sp' num2str(ss)]).Psyn_pixel(ii,jj,i1:i2,:),4);
            np_lambda_pixel(ii,jj,:) = sum(ST.data.(['sp' num2str(ss)]).np_pixel(ii,jj,i1:i2,:),4);
            
            Psyn_pixel(ii,jj) = trapz(lambda(i1:i2),Psyn_lambda_pixel(ii,jj,:));
            np_pixel(ii,jj) = sum(np_lambda_pixel(ii,jj,:),3);
        end
    end
    
    for ii=1:NR
        for jj=1:NZ
            Psyn_lambda_pplane(ii,jj,:) = sum(ST.data.(['sp' num2str(ss)]).Psyn_pplane(ii,jj,i1:i2,:),4);
            np_lambda_pplane(ii,jj,:) = sum(ST.data.(['sp' num2str(ss)]).np_pplane(ii,jj,i1:i2,:),4);
            
            Psyn_pplane(ii,jj) = trapz(lambda(i1:i2),Psyn_lambda_pplane(ii,jj,:));
            np_pplane(ii,jj) = sum(np_lambda_pplane(ii,jj,:),3);
        end
    end
    
    % Convert from m to nm
    axis_lambda = 1E9*lambda(i1:i2);
    Psyn_lambda_pixel = 1E-9*Psyn_lambda_pixel;
    
    h = figure;
    subplot(4,2,[1 3])
    surfc(xAxis,yAxis,Psyn_pixel','LineStyle','none')
    colormap(jet); hc = colorbar('Location','southoutside');
    xlabel(hc,'$P_{syn}$ (Photon/s)','Interpreter','latex','FontSize',12)
    box on; axis square;view([0 -90])
    ylabel('$y$-axis','FontSize',12,'Interpreter','latex')
    xlabel('$x$-axis','FontSize',12,'Interpreter','latex')
    
    figure(h);
    subplot(4,2,5)
%     hold on
%     for ii=1:NX
%         for jj=1:NY
%             plot(axis_lambda,squeeze(Psyn_lambda_pixel(ii,jj,:)))
%         end
%     end
%     hold off
    box on;
    ylabel('$P_{syn}$ (Photon/s/nm)','FontSize',12,'Interpreter','latex')
    xlabel('$\lambda$ (nm)','FontSize',12,'Interpreter','latex')
      
    figure(h);
    subplot(4,2,[2 4])
    surfc(xAxis,yAxis,np_pixel','LineStyle','none')
    colormap(jet);  hc = colorbar('Location','southoutside');
    xlabel(hc,'Number of RE','Interpreter','latex','FontSize',12)
    box on; axis square;view([0 -90])
    ylabel('$y$-axis','FontSize',14,'Interpreter','latex')
    xlabel('$x$-axis','FontSize',14,'Interpreter','latex')
    
    figure(h);
    subplot(4,2,6)
%     hold on
%     for ii=1:NX
%         for jj=1:NY
%             plot(axis_lambda,squeeze(np_lambda_pixel(ii,jj,:)))
%         end
%     end
%     hold off
    box on;
    ylabel('Number of RE','FontSize',12,'Interpreter','latex')
    xlabel('$\lambda$ (nm)','FontSize',12,'Interpreter','latex')    
    
    figure(h);
    subplot(4,2,[7 8])
    yyaxis left 
    set(gca,'YColor',[0,0,1])
    fy = squeeze(sum(sum(Psyn_lambda_pixel,1),2));
%     fy = fy/max(fy);
    plot(axis_lambda,fy,'b','LineWidth',2)
    ylabel('$P_{syn}$ (Photon/s/nm)','FontSize',12,'Interpreter','latex')
    ylim([0 max(fy)])
    yyaxis right
    set(gca,'YColor',[1,0,0])
    fy = squeeze(sum(sum(np_lambda_pixel,1),2));
    plot(axis_lambda,fy,'r','LineWidth',2)
    ylim([0 max(fy)])
    ylabel('Number of RE','FontSize',12,'Interpreter','latex')
    box on;
    xlim([min(axis_lambda) max(axis_lambda)])
    xlabel('$\lambda$ (nm)','FontSize',12,'Interpreter','latex')
    
%     saveas(h,[ST.path 'SyntheticCameraFortran_pixel_ss_' num2str(ss)],'fig')
    
    
    g = figure;
    subplot(4,2,[1 3])
    surfc(RAxis,ZAxis,Psyn_pplane','LineStyle','none')
    colormap(jet); hc = colorbar('Location','southoutside');
    xlabel(hc,'$P_{syn}$ (Photon/s)','Interpreter','latex','FontSize',12)
    box on; axis square;view([0 -90])
    ylabel('$Z$-axis','FontSize',12,'Interpreter','latex')
    xlabel('$R$-axis','FontSize',12,'Interpreter','latex')
    
    figure(g);
    subplot(4,2,5)
    hold on
    for ii=1:NR
        for jj=1:NZ
            plot(axis_lambda,squeeze(Psyn_lambda_pplane(ii,jj,:)))
        end
    end
    hold off
    box on;
    ylabel('$P_{syn}$ (Photon/s/nm)','FontSize',12,'Interpreter','latex')
    xlabel('$\lambda$ (nm)','FontSize',12,'Interpreter','latex')
      
    figure(g);
    subplot(4,2,[2 4])
    surfc(RAxis,ZAxis,np_pplane','LineStyle','none')
    colormap(jet);  hc = colorbar('Location','southoutside');
    xlabel(hc,'Number of RE','Interpreter','latex','FontSize',12)
    box on; axis square;view([0 -90])
    ylabel('$Z$-axis','FontSize',14,'Interpreter','latex')
    xlabel('$R$-axis','FontSize',14,'Interpreter','latex')
    
    figure(g);
    subplot(4,2,6)
    hold on
    for ii=1:NR
        for jj=1:NZ
            plot(axis_lambda,squeeze(np_lambda_pplane(ii,jj,:)))
        end
    end
    hold off
    box on;
    ylabel('Number of RE','FontSize',12,'Interpreter','latex')
    xlabel('$\lambda$ (nm)','FontSize',12,'Interpreter','latex')    
    
    figure(g);
    subplot(4,2,[7 8])
    yyaxis left 
    set(gca,'YColor',[0,0,1])
    fy = squeeze(sum(sum(Psyn_lambda_pplane,1),2));
    fy = fy/max(fy);
    plot(axis_lambda,fy,'b','LineWidth',2)
    ylabel('$P_{syn}$ (Photon/s/nm)','FontSize',12,'Interpreter','latex')
    ylim([0 max(fy)])
    yyaxis right
    set(gca,'YColor',[1,0,0])
    fy = squeeze(sum(sum(np_lambda_pplane,1),2));
    plot(axis_lambda,fy,'r','LineWidth',2)
    ylim([0 max(fy)])
    ylabel('Number of RE','FontSize',12,'Interpreter','latex')
    box on;
    xlim([min(axis_lambda) max(axis_lambda)])
    xlabel('$\lambda$ (nm)','FontSize',12,'Interpreter','latex')
    
%     saveas(g,[ST.path 'SyntheticCameraFortran_pplane_ss_' num2str(ss)],'fig')
end
end

function generateFigures(ST)
disp('Plotting snapshots...')

lambda = ST.params.synthetic_camera_params.lambda;
xAxis = ST.params.synthetic_camera_params.pixels_nodes_x;
yAxis = ST.params.synthetic_camera_params.pixels_nodes_y;

NX = ST.params.synthetic_camera_params.num_pixels(1);
NY = ST.params.synthetic_camera_params.num_pixels(2);

RAxis = ST.params.poloidal_plane_params.nodes_R;
ZAxis = ST.params.poloidal_plane_params.nodes_Z;
NR = ST.params.poloidal_plane_params.grid_dims(1);
NZ = ST.params.poloidal_plane_params.grid_dims(1);

[~,i1] = min(abs(lambda - ST.lambdas(1)));
[~,i2] = min(abs(lambda - ST.lambdas(2)));
Nl = i2 - i1 + 1;

for ss=1:ST.params.simulation.num_species
    disp(['Species: ' num2str(ss)])
    Psyn_lambda_pixel = zeros(NX,NY,Nl);
    np_lambda_pixel = zeros(NX,NY,Nl);
    Psyn_pixel = zeros(NX,NY);
    np_pixel = zeros(NX,NY);
    
    Psyn_lambda_pplane = zeros(NR,NZ,Nl);
    np_lambda_pplane = zeros(NR,NZ,Nl);
    Psyn_pplane = zeros(NR,NZ);
    np_pplane = zeros(NR,NZ);

    PTot = zeros(NR,NZ);
        
    for ii=1:NX
        for jj=1:NY
            Psyn_lambda_pixel(ii,jj,:) = sum(ST.data.(['sp' num2str(ss)]).Psyn_pixel(ii,jj,i1:i2,:),4);
            np_lambda_pixel(ii,jj,:) = sum(ST.data.(['sp' num2str(ss)]).np_pixel(ii,jj,i1:i2,:),4);
            
            Psyn_pixel(ii,jj) = trapz(lambda(i1:i2),Psyn_lambda_pixel(ii,jj,:));
            np_pixel(ii,jj) = sum(np_lambda_pixel(ii,jj,:),3);
        end
    end
    
    for ii=1:NR
        for jj=1:NZ
            Psyn_lambda_pplane(ii,jj,:) = sum(ST.data.(['sp' num2str(ss)]).Psyn_pplane(ii,jj,i1:i2,:),4);
            np_lambda_pplane(ii,jj,:) = sum(ST.data.(['sp' num2str(ss)]).np_pplane(ii,jj,i1:i2,:),4);
            
            Psyn_pplane(ii,jj) = trapz(lambda(i1:i2),Psyn_lambda_pplane(ii,jj,:));
            np_pplane(ii,jj) = sum(np_lambda_pplane(ii,jj,:),3);
            
            PTot(ii,jj) = sum(abs(ST.data.(['sp' num2str(ss)]).PTot_pplane(ii,jj,:)),3);
        end
    end
    
    % Convert from m to nm
    axis_lambda = 1E9*lambda(i1:i2);
    Psyn_lambda_pixel = 1E-9*Psyn_lambda_pixel;
    
    
    h = figure;
    
    nt = 100;
    t = linspace(0,2*pi,nt);
    x = ST.params.fields.Ro + ST.params.fields.a*cos(t);
    y = ST.params.fields.a*sin(t);
    
    xpixel = zeros(1,nt);
    ypixel = zeros(1,nt);
    
    Rc = ST.params.synthetic_camera_params.position(1);
    Zc = ST.params.synthetic_camera_params.position(2);
    f = ST.params.synthetic_camera_params.focal_length;
    incline = deg2rad(ST.params.synthetic_camera_params.incline);
    
%     ax = atan(x./Rc);
%     axo = pi/2 - incline;
%     d = sqrt(Rc^2 + x.^2);
%     ay = atan(y./d);
%     
%     for tt=1:nt
%         xpixel(tt) = -f*tan(axo - ax(tt));
%         ypixel(tt) = -f*tan(ay(tt));
%     end
    
    % Last closed surface
    m = -tan(pi/2 - incline);
    n = tan(incline);
    
    xo = m*Rc/(m - n);
    yo = xo*tan(incline);
    Ro = sqrt(xo^2 + yo^2);

    xperp = zeros(1,nt);
    yperp = zeros(1,nt);
    
    for tt=1:nt
        xtmp = cos(incline)*x(tt);
        ytmp = sin(incline)*x(tt);
        d = sqrt( (xtmp - Rc)^2 + ytmp^2 );
        
        yperp(tt)= -f*y(tt)/d;
        
        xperp(tt) = f*(x(tt)-Ro)/d;
    end
    % Last closed surface
    
    % Magnetic axis
    xtmp = cos(incline)*ST.params.fields.Ro;
    ytmp = sin(incline)*ST.params.fields.Ro;
    d = sqrt( (xtmp - Rc)^2 + ytmp^2 );
    
    ymag_axis = 0;  
    xmag_axis = f*(ST.params.fields.Ro-Ro)/d;
    % Magnetic axis

    % Initial condition
    xic = ST.params.species.Ro(ss) + ST.params.species.r(ss)*cos(t);
    yic = ST.params.species.r(ss)*sin(t);
        
    for tt=1:nt
        xtmp = cos(incline)*xic(tt);
        ytmp = sin(incline)*xic(tt);
        d = sqrt( (xtmp - Rc)^2 + ytmp^2 );
        
        ypixel(tt)= -f*yic(tt)/d;
        xpixel(tt) = f*(xic(tt)-Ro)/d;
    end
    % Initial condition
    
    iv = 18;
    
    A = PTot';
    minval = min(min(A));
    maxval = max(max(A));
    v = linspace(minval,maxval,21);
        
    figure(h);
    subplot(2,3,1)
%     surfc(RAxis,ZAxis,PTot','LineStyle','none')
    contourf(RAxis,ZAxis,A,v(1:iv),'LineStyle','none')
    hold on;plot(x,y,'w','Linewidth',2);hold off
    colormap(jet); hc = colorbar('Location','southoutside');
    xlabel(hc,'$P_{Tot}$ (Watts)','Interpreter','latex','FontSize',12)
    box on; axis square;view([0 -90])
    ylabel('$Z$-axis','FontSize',12,'Interpreter','latex')
    xlabel('$R$-axis','FontSize',12,'Interpreter','latex')
    
    
    A = Psyn_pixel';
    minval = min(min(A));
    maxval = max(max(A));
    v = linspace(minval,maxval,21);
    
    figure(h);
    subplot(2,3,2)
%     surfc(xAxis,yAxis,A,'LineStyle','none')
    contourf(xAxis,yAxis,A,v(1:iv),'LineStyle','none')
    hold on;plot(xpixel,ypixel,'w--','Linewidth',1);hold off
    hold on;plot(xperp,yperp,'w','Linewidth',2);hold off
    hold on;plot(xmag_axis,ymag_axis,'wx','Markersize',6,'LineWidth',2);hold off
    colormap(jet); hc = colorbar('Location','southoutside');
    xlabel(hc,'$P_{syn}$ (Photon/s)','Interpreter','latex','FontSize',12)
    box on; axis square;view([0 -90])
    ylabel('$y$-axis','FontSize',12,'Interpreter','latex')
    xlabel('$x$-axis','FontSize',12,'Interpreter','latex')
    
    
    A = Psyn_pplane';
    minval = min(min(A));
    maxval = max(max(A));
    v = linspace(minval,maxval,21);
    
    figure(h);
    subplot(2,3,3)
%     surfc(RAxis,ZAxis,Psyn_pplane','LineStyle','none')
    contourf(RAxis,ZAxis,A,v(1:iv),'LineStyle','none')
    hold on;plot(x,y,'w','Linewidth',2);hold off
    colormap(jet); hc = colorbar('Location','southoutside');
    xlabel(hc,'$P_{syn}$ (Photon/s)','Interpreter','latex','FontSize',12)
    box on; axis square;view([0 -90])
    ylabel('$Z$-axis','FontSize',12,'Interpreter','latex')
    xlabel('$R$-axis','FontSize',12,'Interpreter','latex')
    
    figure(h);
    subplot(2,3,4)
    f = squeeze(sum(sum(Psyn_lambda_pixel,1),2));
    f = f/max(f);
    g = squeeze(sum(sum(Psyn_lambda_pplane,1),2));
    g = g/max(g);
    plot(axis_lambda,f,'b',axis_lambda,g,'r','LineWidth',2)
    ylabel('$P_{syn}$ (A.U.)','FontSize',12,'Interpreter','latex')
    xlim([min(axis_lambda) max(axis_lambda)])
    xlabel('$\lambda$ (nm)','FontSize',12,'Interpreter','latex')
    legend({'$P_{syn}(\lambda,\psi,\chi)$','$P_{syn}(\lambda)$'},'Interpreter','latex')
      
    
    A = np_pixel';
    minval = min(min(A));
    maxval = max(max(A));
    v = linspace(minval,maxval,21);
    
    figure(h);
    subplot(2,3,5)
%     surfc(xAxis,yAxis,np_pixel','LineStyle','none')
    contourf(xAxis,yAxis,A,v(1:iv),'LineStyle','none')
    hold on;plot(xpixel,ypixel,'w--','Linewidth',1);hold off
    hold on;plot(xperp,yperp,'w','Linewidth',2);hold off
    hold on;plot(xmag_axis,ymag_axis,'wx','Markersize',6,'LineWidth',2);hold off
    colormap(jet);  hc = colorbar('Location','southoutside');
    xlabel(hc,'Number of RE','Interpreter','latex','FontSize',12)
    box on; axis square;view([0 -90])
    ylabel('$y$-axis','FontSize',14,'Interpreter','latex')
    xlabel('$x$-axis','FontSize',14,'Interpreter','latex')
    
    
    A = np_pplane';
    minval = min(min(A));
    maxval = max(max(A));
    v = linspace(minval,maxval,21);
    
    figure(h);
    subplot(2,3,6)
%     surfc(RAxis,ZAxis,np_pplane','LineStyle','none')
    contourf(RAxis,ZAxis,A,v(1:iv),'LineStyle','none')
    hold on;plot(x,y,'w','Linewidth',2);hold off
    colormap(jet);  hc = colorbar('Location','southoutside');
    xlabel(hc,'Number of RE','Interpreter','latex','FontSize',12)
    box on; axis square;view([0 -90])
    ylabel('$Z$-axis','FontSize',14,'Interpreter','latex')
    xlabel('$R$-axis','FontSize',14,'Interpreter','latex')
    
    saveas(h,[ST.path 'SyntheticCamera_ss_' num2str(ss)],'fig')
end
end