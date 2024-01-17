function hdf5viewer(NWBfn)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% create a UIFigure for viewing hdf5 file 
%---------------------------------------------
% Tested Under MATLAB Version 9.12.0 (R2022a)
% Time-stamp: <2024-Jan-17> 
%---------------------------------------------
%
% Xinyue Ma, PhD student
% Email: xinyue.ma@mail.mcgill.ca
% Integrated Program in Neuroscience
% McGill University
% Montreal, QC, H3A 1A1 
% Canada
%
%-------------------------------------------
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    screensize = get(0,'screensize');
    fig = uifigure('Resize','off',...
        'Position',[screensize(3)*0.05 screensize(3)*0.05 screensize(3)*0.45 screensize(4)*0.7 ], ...
        'Name','hdf5viewer');
    uifig_pos = fig.Position;    
    pos =  getCompPos(uifig_pos);
    clf(fig)
    
    % - load hdf5 file
    uilabel(fig,'Position',pos.label_file, ...
                'Text',['File fullpath: ', NWBfn]);

    % - display values
    uilabel(fig,'Position',pos.label_path,'Text','Path:','FontWeight','bold');
    uieditfield(fig,'Position',pos.editfield_path,'Editable','off','Tag','path');
    uilabel(fig,'Position',pos.label_value,'Text','Value:','FontWeight','bold');
    uitextarea(fig,'Position',pos.textarea_value,'Editable','off','Tag','value');
    
    % - display hdf5 as a tree
    mytree = uitree(fig,'Position',pos.tree,'SelectionChangedFcn',@(src, event)SelectNodeFcn(src,event));
    uiaxes(fig,'Position',pos.uiaxes_data);
    nwb2Tree(NWBfn, fig, mytree);
    expand(mytree) 
end

function pos =  getCompPos(uifig_pos)
% relative positions of UI components
    pos_percent.label_file = [-5 80 87 3];
    pos_percent.tree = [-5 -9 40 88];
    pos_percent.label_path = [37 76 4 3];
    pos_percent.editfield_path = [42 76 40 3];
    pos_percent.label_value = [37 72 4 3];
    pos_percent.textarea_value = [42 45 40 30];
    pos_percent.uiaxes_data = [40 -9 41 40];

    getpos = @(x,y)[x(1) x(2) 0 0] + [x(3) x(4) x(3) x(4)] .* y .* 0.01;

    pos = struct();
    fname = fieldnames(pos_percent);
    for ifield = 1:length(fname)
        pos = setfield(pos, fname{ifield}, getpos(uifig_pos, getfield(pos_percent, fname{ifield})) );
    end

end

function SelectNodeFcn(src,event)
    
    for ii = 1:length(src.Parent.Children)
        ch = src.Parent.Children(ii);

        % assign the node path to editfield_path
        if isa(ch,'matlab.ui.control.EditField') && strcmp(ch.Tag,'path')
            ch.Value = src.SelectedNodes.Tag;
        end

        % assign value to textarea_value if the node is an attribute
        if isa(ch,'matlab.ui.control.TextArea') && strcmp(ch.Tag,'value')
            nd = src.SelectedNodes.NodeData;
            if isnumeric(nd)
                if numel(nd)>2
                    tg = ['Dataset: [' num2str(size(nd,1)) 'x' num2str(size(nd,2)) ']'];
                else
                    tg = num2str(nd);
                end
            else
                tg = nd;
            end
            ch.Value = tg;
        end
        
        % visualize the data in uiaxes_data
        if isa(ch,'matlab.ui.control.UIAxes') && isnumeric(src.SelectedNodes.NodeData)
            plot(ch,src.SelectedNodes.NodeData);
        end
    end
end

function gName = getgName(fullpath,sep)
    gName = split(fullpath, sep);
    gName = gName{end};
end

function [mytree, pnode] = nwb2Tree(nwbfn, fig, mytree, mystruct, fullpath)
    % https://myhdf5.hdfgroup.org/

    % -- Groups: nested. Name, Groups, Datasets, Datatypes, Links, Attributes
    % -- Datasets: Name, Groups, Datasets, Dataspace, ..., Attributes
    % -- Attributes: Name, ..., Value

    % ———— INPUT
    % nwbfn     | NWB file full location
    % fig       | figure handle
    % mytree    | uitree handle
    % mystruct  | struct of the parent node
    % gName     | fullname of parent node
    % gAttr     | attributes of parent node    

    % ———— Tree nodes description
    % Text: Name of Groups/Datasets/Attributes
    % Tag: path
    % Neurodata: h5read(*Datasets*)

    % - load nwb file into struct
    if nargin == 3
        mystruct = h5info(nwbfn);
        fullpath = nwbfn;
        nwb2Tree(nwbfn, fig, mytree, mystruct, fullpath);
        return
    end

    if isfield(mystruct, 'Groups')

        % - groups
        if strcmp(fullpath, nwbfn)
            gName = getgName(fullpath,filesep);
            mystruct_top = mystruct;
            mystruct = mystruct.Groups;
            istop = 1;
            fullpath = '';
        else
            gName = getgName(fullpath,'/');
            istop = 0;
        end
        
        % - parent Group
        pnode = genNWBNode(mytree, gName, fullpath, '');

        % - child Groups
        for ii = 1:length(mystruct) 

            if ~isempty(mystruct(ii).Groups)
                % load child groups
                [~, cnode] = nwb2Tree(nwbfn, fig, pnode, mystruct(ii).Groups, mystruct(ii).Name);
            else
                % load datasets for the end nodes
                gName = getgName(mystruct(ii).Name,'/');
                % - parent Group
                pnode_datasets = genNWBNode(pnode, gName, mystruct(ii).Name, '');
                nwb2Tree(nwbfn, fig, pnode_datasets, mystruct(ii).Datasets, mystruct(ii).Name);
                
                % - attributes
                genAttrNode(pnode_datasets, mystruct(ii).Attributes, mystruct(ii).Name);
                continue
            end

            % - attributes
            genAttrNode(cnode, mystruct(ii).Attributes, fullpath);

            % - child Datasets     
            nwb2Tree(nwbfn, fig, pnode, mystruct(ii).Datasets, mystruct(ii).Name);

        end  

        % - Datasets at Top level
        if istop
            for jj = 1:length(mystruct_top.Datasets)
                nwb2Tree(nwbfn, fig, pnode, mystruct_top.Datasets(jj),fullpath);                   
            end
            
            % - attributes
            genAttrNode(pnode, mystruct_top.Attributes,fullpath);
        end
        
    else
        % - load Datasets
        for ii = 1:length(mystruct)
            tx = mystruct(ii).Name;
            tg = [fullpath '/' mystruct(ii).Name];
            nd = h5read(nwbfn, tg);
            pnode = genNWBNode(mytree, tx, tg, nd);

            % - attributes
            genAttrNode(pnode, mystruct(ii).Attributes, tg);
        end
    end
end

function genAttrNode(mytree, attrstruct, fullpath)
    if isempty(attrstruct)
        return
    end
    tx = 'Attributes';
    tg = ['[Attributes] ' fullpath];
    pnode = genNWBNode(mytree, tx, tg, '');
    for ii = 1:length(attrstruct)
        tx = attrstruct(ii).Name;
        nd = attrstruct(ii).Value;

        if isnumeric(nd)
            if numel(nd)>2
                tg = ['Dataset: [' num2str(size(nd,1)) 'x' num2str(size(nd,2)) ']'];
            else
                tg = num2str(nd);
            end
        else
            if iscell(nd) && numel(nd) > sum(cellfun(@isempty,nd),"all")
                tg = nd(~cellfun(@isempty,nd));
            else
                tg = nd;
            end
            tg = join(string(tg),' ');
            tg = tg{1};
        end

        tg = ['[Attributes] ' fullpath '/Attributes/' tx ]; % ': ' tg

        genNWBNode(pnode, tx, tg, nd);
    end    
end

function mynode = genNWBNode(pnode, tx, tg, nd)
    mynode = uitreenode(pnode,'Text',tx,'Tag',tg,'NodeData',nd); % ,'ContextMenu',pcm           
end
