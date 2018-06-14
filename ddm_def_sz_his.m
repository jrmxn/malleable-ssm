classdef ddm_def_sz_his < ddm_def_sz
    %DDM_DEF Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
    end
    
    methods
        function obj = ddm_def_sz_his(obj)
            %ovewrite model class property
            obj.modelclass = 'sz_his';
            obj.path_data = fullfile('testing','testing_sz.csv');
            obj.info.difficulties = [-5:5];
            obj.info.name_history = {'h1_stimulus','h1_choice','nlrt'};
        end
        
        function get_data(obj)
            get_data@ddm_def_sz(obj);
            %the meat of the difference to ddm_def_sz_eeg goes here
        end
        
        function p_mat = ddm_cost_add_stim_dependencies(obj,p_mat)
            p_mat = ddm_cost_add_stim_dependencies@ddm_def_sz(obj,p_mat);

            for ix_name_history = 1:length(obj.info.name_history)
                p_mat.(obj.info.name_history{ix_name_history}) = ...
                    obj.data.(obj.info.name_history{ix_name_history});
            end
        end
        
    end
    
    methods (Access = protected)
        function [modelkey_var,pran_,pdef_,plbound_,pubound_,prior_] = ddm_def_instance(obj)
            function [modelkey_var,pran_,pdef_,plbound_,pubound_,prior_] = def_his_params(p_, g_sd)
                modelkey_var = (p_);
                pd_hn_i = makedist('Normal','mu',0,'sigma',g_sd);
                pran_ = pd_hn_i.random;
                pdef_ = 0.0;
                plbound_ = -5*g_sd;
                pubound_ = +5*g_sd;
                prior_ = @(x) pdf(pd_hn_i,x);
            end
            
            [modelkey_var,pran_,pdef_,plbound_,pubound_,prior_] = ddm_def_instance@ddm_def_sz(obj);
            ix = length(modelkey_var)+1;
            
            % we can put his based noise on...
            for ix_name_history = 1:length(obj.info.name_history)
            p_ = sprintf('%s_%s','t',obj.info.name_history{ix_name_history});
            [modelkey_var{ix},pran_.(p_),pdef_.(p_),plbound_.(p_),pubound_.(p_),prior_.(p_)] ...
                = def_his_params(p_, 0.1);ix = ix+1;
            p_ = sprintf('%s_%s','z',obj.info.name_history{ix_name_history});
            [modelkey_var{ix},pran_.(p_),pdef_.(p_),plbound_.(p_),pubound_.(p_),prior_.(p_)] ...
                = def_his_params(p_, 0.1);ix = ix+1;
            p_ = sprintf('%s_%s','v',obj.info.name_history{ix_name_history});
            [modelkey_var{ix},pran_.(p_),pdef_.(p_),plbound_.(p_),pubound_.(p_),prior_.(p_)] ...
                = def_his_params(p_, 0.1);ix = ix+1;
            end
        end
    end
    
    methods (Static)
        
        function  [pdf_,p_cr] = ddm_prt_ana(p, rt, his_mod)
            err = 1e-8;
            diffi_str = ddm_def_sz.diff2drift(p.difficulty);
            px = p;
            %n.b. don't just inherit from parent - this has to sandwhich
            %inside the definition, because parent overwrites v.
            %n.b. the re-assignment to v here is also critical for v_his interactions
            px.v = px.(diffi_str);
            for ix_his_mod = 1:length(his_mod)
                ch_str = his_mod(ix_his_mod).channel;
                p_str = his_mod(ix_his_mod).param;
                if not(isfield(px,ch_str)),error('Are the stim dependencies set? Is %s in your data?',ch_str);end
                if strcmpi(p_str,'v')
                    px.(p_str) = px.(p_str) * ...
                        (1+px.(ch_str) * px.(sprintf('%s_%s',p_str,ch_str)));
                else
                px.(p_str) = px.(p_str) + ...
                    px.(ch_str) * px.(sprintf('%s_%s',p_str,ch_str));
                end
            end
            
            p_cr = ddm_def.hddm_prob_ub(px.v,px.a,px.z);
            h_pdf = @(x) ddm_def.hddm_pdf_full(x,px.v,px.sv,px.a,px.z,px.sz,px.t,px.st,err);
            pdf_ = arrayfun(@(x) h_pdf(x),+rt);
            
        end
        
    end
end