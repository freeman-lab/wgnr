function register_directory(start_trial,num_files,tot_files,align_chan,save_opts,handles)

global im_session;

num_planes = im_session.ref.im_props.numPlanes;
num_chan = im_session.ref.im_props.nchans;
behaviour_val = get(handles.checkbox_behaviour,'Value');

base_name = [im_session.basic_info.anm_str '_' im_session.basic_info.date_str '_' im_session.basic_info.run_str '_'];

set(handles.text_frac_registered,'String',sprintf('Registered %d/%d',start_trial-1,tot_files))
drawnow

% Go through new files
for ij = start_trial:num_files
	
	% define current file name
	set(handles.text_frac_registered,'String',sprintf('Registered %d/%d',ij-1,tot_files))
	%drawnow
	cur_file = fullfile(im_session.basic_info.data_dir,im_session.basic_info.cur_files(ij).name);
	trial_name = cur_file(end-6:end-4);

	% define summary name
	type_name = 'summary';
	file_name = [im_session.basic_info.anm_str '_' im_session.basic_info.date_str '_' im_session.basic_info.run_str '_' type_name '_' trial_name '.mat'];
	folder_name = fullfile(im_session.basic_info.data_dir,type_name);
	summary_file_name = fullfile(folder_name,file_name);
	
	% if overwrite is off and summary file exists load it in
	if save_opts.overwrite ~= 1 && exist(summary_file_name) == 2
		set(handles.text_status,'String','Status: loading existing')
		drawnow
		load(summary_file_name);
		im_raw = [];
		im_aligned = [];
	else % Otherwise register file
		set(handles.text_status,'String','Status: registering')
		drawnow
		% register file
		[im_raw im_aligned im_summary] = register_file(cur_file,base_name,im_session.ref,align_chan,ij);	
		% save summary data
		save(summary_file_name,'im_summary');
		% save registered data
		if save_opts.aligned == 1
			set(handles.text_status,'String','Status: saving aligned')
    		if get(handles.togglebutton_online_mode,'value') == 1
    			time_elapsed = toc;
 				time_elapsed_str = sprintf('Time online %.1f s',time_elapsed);
    			set(handles.text_time,'String',time_elapsed_str)
			end
			drawnow
			type_name = 'registered';
			file_name = [im_session.basic_info.anm_str '_' im_session.basic_info.date_str '_' im_session.basic_info.run_str '_' type_name '_' trial_name '.mat'];
			folder_name = fullfile(im_session.basic_info.data_dir,type_name);
			full_file_name = fullfile(folder_name,file_name);
			save(full_file_name,'im_aligned');
		end
	end

	% extract behaviour information if necessary
	if behaviour_val == 1
		if get(handles.togglebutton_online_mode,'value') == 0
			global behaviour_scim_trial_align;
			behaviour_trial_num = behaviour_scim_trial_align(ij);
		else
			behaviour_trial_num = ij;
		end
		global session;	
		scim_trig_vect = session.data{behaviour_trial_num}.processed_matrix(6,:);
		im_summary = extract_behviour_scim_data(im_summary,scim_trig_vect,behaviour_trial_num);
		trial_data_raw = session.data{behaviour_trial_num};
		scim_frame_trig = im_summary.behaviour.align_vect;
		[trial_data data_variable_names] = parse_behaviour2im(trial_data_raw,behaviour_trial_num,scim_frame_trig);
  		type_name = 'parsed_behaviour';
		file_name = [im_session.basic_info.anm_str '_' im_session.basic_info.date_str '_' im_session.basic_info.run_str '_' type_name '_' trial_name '.mat'];
		folder_name = fullfile(im_session.basic_info.data_dir,type_name);
		full_file_name = fullfile(folder_name,file_name);
		save(full_file_name,'trial_data','data_variable_names');
	else
		trial_data = [];
  	end



	% save text file
	if save_opts.text == 1 && isempty(im_aligned) ~=1
		set(handles.text_status,'String','Status: saving text')
		if get(handles.togglebutton_online_mode,'value') == 1
    		time_elapsed = toc;
 			time_elapsed_str = sprintf('Time online %.1f s',time_elapsed);
    		set(handles.text_time,'String',time_elapsed_str)
		end
		drawnow
		type_name = 'text';
		file_name = [im_session.basic_info.anm_str '_' im_session.basic_info.date_str '_' im_session.basic_info.run_str '_' type_name '_' trial_name '.txt'];
		folder_name = handles.text_path;
		full_file_name = fullfile(folder_name,file_name);
		analyze_chan = str2double(get(handles.edit_analyze_chan,'String'));
		save_im2text(im_aligned,im_summary,trial_data,analyze_chan,full_file_name);
	end

	set(handles.text_status,'String','Status: updating')
	drawnow

	% update im_session	
	tmp_raw_mean = zeros(im_session.ref.im_props.height,im_session.ref.im_props.width,num_planes,num_chan,1);
	tmp_align_mean = zeros(im_session.ref.im_props.height,im_session.ref.im_props.width,num_planes,num_chan,1);
	for ih = 1:num_chan
		for ik = 1:num_planes
			% extract mean images and summary data for each plane 
			tmp_raw_mean(:,:,ik,ih,1) = im_summary.mean_raw{ik,ih};
			tmp_align_mean(:,:,ik,ih,1) = im_summary.mean_aligned{ik,ih};
		end
	end
	im_session.reg.nFrames = cat(1,im_session.reg.nFrames, im_summary.props.num_frames);
	im_session.reg.startFrame = cat(1,im_session.reg.startFrame, im_summary.props.firstFrame);
	im_session.reg.raw_mean = cat(5,im_session.reg.raw_mean, tmp_raw_mean);
	im_session.reg.align_mean = cat(5,im_session.reg.align_mean, tmp_align_mean);
	
	if num_files > 0 & start_trial > 0
		set(handles.slider_trial_num,'max',ij)
		set(handles.slider_trial_num,'SliderStep',[1/(ij+1) 1/(ij+1)])
	end

	set(handles.text_frac_registered,'String',sprintf('Registered %d/%d',ij,tot_files))

	update_im = get(handles.checkbox_plot_images,'value');
	if update_im == 1 & start_trial > 0
		set(handles.edit_trial_num,'String',num2str(ij));
		set(handles.slider_trial_num,'Value',ij);
		im_data = plot_im_gui(handles,0);
		im_plot = get(handles.axes_images,'Children');
		set(im_plot,'CData',im_data)
	end

    if get(handles.togglebutton_online_mode,'value') == 1
    	time_elapsed = toc;
 		time_elapsed_str = sprintf('Time online %.1f s',time_elapsed);
    	set(handles.text_time,'String',time_elapsed_str)
	end
	
	drawnow
end

set(handles.text_status,'String','Status: waiting')
drawnow

end



