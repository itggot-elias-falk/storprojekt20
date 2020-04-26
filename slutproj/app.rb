require "sinatra"
require "slim"
require "bcrypt"
require "sqlite3"
require "fileutils"
require "date"
require_relative "./model.rb"

enable :sessions

before do
    path = request.path_info
    if (session[:user_id] == nil || session[:user_id] == 0) && (path != "/" && path != "/register" && path != "/home" && path != "/login" && path != "/error")
        p "redirecting"
        redirect("/")
    end
end

before "/files/:file_id/edit" do
    p "authenticating file access"
    file_id = params[:file_id]
    if !has_access_to_file(file_id, session[:user_id])
        p "does not have access"
        redirect("#{session[:last_route]}")
    end
end

after do
    session[:last_route] = request.path
    p "last route: #{session[:last_route]}"
end

def add_login_attempt()
    session[:login_attempt] += 1
    p "login attemps = #{session[:login_attempt]}"
    if session[:login_attempt] >= 2
        session[:start_time] = Time.new.to_i
        p "start time = #{session[:start_time]}"
        session[:timeout] = true
        session[:login_attempt] = 0
    end


end

def update_timeout_status()
    if session[:timeout] == true
        current_time = Time.new.to_i
        p "current time = #{current_time}"
        diff = current_time - session[:start_time]
        p "curr - start = #{diff}"
        time_out_length = 300
        if diff >= time_out_length
            session[:timeout] = false
        else
            session[:time_left] = time_out_length - diff
        end
    end
end


# Displays the login screen
#
get("/") do
    update_timeout_status()
    if session[:user_id] != 0 && session[:user_id] != nil
        redirect("/home")
    end
    if session[:login_attempt] == nil
        session[:login_attempt] = 0
    end
    if session[:timeout] == nil
        session[:timeout] = false
    end
    session[:username] = ""
    session[:email] = ""
    session[:user_id] = 0
    if session[:rank] == nil
        session[:rank] = 0
    end
    slim(:"users/index")
end

# Displays the error code
#
get("/error") do
    slim(:error)
end

# Displays the register view
#
get("/register") do
    slim(:"users/register")
end

# Creates a new user and redirects to '/home'
#
# @param [String] username, the username of the the user
# @param [String] email, the email of the user
# @param [String] password, the password of the user
# @param [String] confirm_password, the confirmed password of the user
# 
# @see Model#email_exist
# @see Model#username_exist
# @see Model#register_user
post("/register") do
    email = params[:email].downcase
    username = params[:username]
    password = params[:password]
    confirm_password = params[:confirm_password]

    if email_exist(email)
        session[:register_username] = username
        session[:error] = "email already exists"
        redirect("/error")
    end

    if username_exist(username)
        session[:register_email] = email
        session[:error] = "username already taken"
        redirect("/error")
    end

    if password != confirm_password
        session[:register_email] = email
        session[:register_username] = username
        session[:register_password] = password
        session[:error] = "passwords does not match"
        redirect("/error")
    end

    password_digest = BCrypt::Password.create(password)
    register_user(email, username, password_digest, 0, username.downcase)
    session[:username] = username
    session[:email] = email
    session[:user_id] = get_user_id_for_username(username)
    session[:rank] = 0
    # db.execute("INSERT INTO folders (owner_id, folder_name) VALUES (?, ?)", session[:user_id], session[:user_id])

    redirect("/home")
end


# Changes the login status of the user and redirects to '/home'
# 
# @param [String] email, the email of the user
# @param [String] password, the password the user
#
# @see Model#email_exist
# @see Model#validate_password
# @see Model#get_user_data
post("/login") do
    update_timeout_status()
    if session[:timeout]
        redirect("/")
    end
    email = params[:email].downcase
    password = params[:password]
    p "checking email"
    if !email_exist(email)
        session[:error] = "wrong email"
        add_login_attempt()
        redirect("/error")
    end

    p "checking password"
    if !validate_password(email, password)
        session[:error] = "wrong password"
        add_login_attempt()
        redirect("/error")
    end

    p "login success"
    session[:attempt] = 0
    session[:email] = email
    user_data = get_user_data(email)
    session[:user_id] = user_data[:user_id]
    session[:username] = user_data[:username]
    session[:rank] = user_data[:rank]
    redirect("/home")
end


# Displays all files set to public
#
# @see Model#get_all_public_files
get("/home") do
    public_files = get_all_public_files()
    slim(:"files/show_public", locals:{public_files: public_files})
end

# Changes the login status of the user to logged out and redirects to '/'
post("/logout") do
    session.clear
    redirect("/")
end

# Displays a change password and email form
#
get("/user") do
    slim(:"users/edit")
end

def create_file(file_id, filename, file)
    Dir.mkdir "./public/uploads/#{file_id}"
    path = "./public/uploads/#{file_id}/#{filename}"
    File.open(path, 'wb') do |f|
        f.write(file.read)
    end
end

def rename_file(file_id, old_filename, new_filename)
    path = "./public/uploads/#{file_id}"
    if old_filename != new_filename
        FileUtils.mv("#{path}/#{old_filename}", "#{path}/#{new_filename}")
    end
end

# Displays a upload file form
#
get("/files/upload") do
    if session[:user_id] == nil
        redirect("/")
    end
    user_folders = get_all_folderdata_for_user_id(session[:user_id])
    slim(:"files/upload", locals: {user_folders: user_folders})
end

# Attempts to upload a file and redirects to the last route
# 
# @param [Hash] file_info, the information of the file being uploaded
# @param [String] filename, the user given name of the file being uploaded
# @param [Integer] folder_id, the id of the folder in which the file will be placed
# @param [String] public_status, the public status of the file being uploaded
#
# @see Model#file_name_exist
# @see Model#insert_file_into_db
# @see Model#get_single_file_id
# @see Model#create_file
# @see Model#update_file_size
post("/files/upload") do
    file_info = params[:file]
    if file_info && file_info[:filename]

        if params[:file_name] == ""
            filename = file_info[:filename]
        else
            filename = params[:file_name] + "." + file_info[:filename].split(".")[1]
        end

        file = file_info[:tempfile]
        file_type = file_info[:type]
        folder_id = params[:folder].chomp.to_i
        public_status = params[:public]
        if params[:public] == "on"
            public_status = 1
        else
            public_status = 0
        end

        if file_name_exist(filename, session[:user_id])
            redirect("/upload")
        end

        time = Time.new.inspect.split(" +")[0]
        
        insert_file_into_db(session[:user_id],filename,time,time,file_type,0,folder_id,public_status)
        file_id = get_single_file_id(filename, session[:user_id])
        create_file(file_id, filename, file)
        file_size = File.size("./public/uploads/#{file_id}/#{filename}")
        update_file_size(file_id, file_size)
    end
    redirect("#{session[:last_route]}")
end


# Attempts to download a file and redirects to the last route
#
# @param [Integer] :file_id, the id of the file being downloaded
# @param [String] filename, the name of the file being downloaded
# @param [String] time, the time of which the file is being downloaded
#
# @see Model#update_last_access
post("/files/:file_id/download") do
    file_id = params[:file_id]
    filename = get_file_data(file_id)["file_name"]
    time = Time.new.inspect.split(" +")[0]
    update_last_access(file_id, time)
    send_file("./public/uploads/#{file_id}/#{filename}", :filename=>filename, :type=>"application/octet-stream")
    redirect("#{session[:last_route]}")
end

# Attempts to the delete a file and redirects to the last route
# 
# @param :file_id, the id of the file being deleted
# 
# @see Model#delete_file_from_db
post("/files/:file_id/delete") do
    file_id = params[:file_id]
    FileUtils.remove_dir("./public/uploads/#{file_id}")
    delete_file_from_db(file_id)
    redirect("#{session[:last_route]}")
end

before("/files/all") do
    if session[:rank] < 1
        redirect("#{last_route}")
    end
end


# Displays all the files in the database
#
# @see Model#get_all_files
get("/files/all") do
    all_files = get_all_files()
    slim(:"files/show_all", locals: {all_files: all_files})
end

# Displays all the files owned or shared with the user
#
# @see Model#get_all_shared_files_for_user
get("/files") do
    owned_files = get_all_owned_files(session[:user_id])

    shared_files = get_all_shared_files_for_user(session[:user_id])
    p shared_files
    slim(:"files/show_user_files", locals: {shared_files: shared_files, owned_files: owned_files})
end

# Displays a form to edit, share and unshare a file
# 
# @param [Integer] :file_id, the id of the file being edited
#
# @see Model#get_file_data
# @see Model#get_users_with_access
# @see Model#get_all_user_data
# @see Model#get_all_folderdata_for_user_id
get("/files/:file_id/edit") do
    file_id = params["file_id"]
    file = get_all_file_data(file_id).first
    user_ids_with_access = get_users_with_access(file_id)
    
    usernames = []
    users_with_access = []
    if user_ids_with_access != []
        user_ids_with_access.each do |user_id|
            users_with_access << get_all_user_data(user_id["user_id"]).first
        end
    end

    user_folders = get_all_folderdata_for_user_id(session[:user_id])
    current_folder = get_all_folderdata_for_folder_id(file["folder_id"]).first

    slim(:"files/edit", locals:{file_id: file_id, file: file, users_with_access: users_with_access, user_folders: user_folders, current_folder: current_folder})
end

# Attempts to update a file and redirects to the last route
#
# @param [Integer] :file_id, the id of the file being updated
# @param [String] old_filename, the old name of the file being updated
# @param [String] filename, the new name of the file being updated
# @param [Integer] public_status, the public status of the file being updated
# @param [String] share_usernames, the usernames of the users that the file will be shared with
# @param [Integer] folder_id, the id of the folder the file is being placed in
#
# @see Model#get_file_data
# @see Model#get_user_id_for_username
# @see Model#already_shared
# @see Model#share_file_with_user
# @see Model#update_file_in_db
post("/files/:file_id/update") do
    file_id = params[:file_id]
    old_filename = get_file_data(file_id)["file_name"]
    filename = params[:file_name]
    public_status = params[:public_status]
    share_usernames = params[:share_usernames].split(", ")
    folder_id = params[:folder]

    if share_usernames
        share_usernames.each do |username|
            # TODO: make it work with lowercase usernames
            user_id = get_user_id_for_username(username)

            if !user_id
                session[:error] = "no such user exists"
                redirect("/error")
            elsif user_id != [] && !already_shared(user_id, file_id) && user_id != session[:user_id]
                share_file_with_user(user_id, file_id)
            else
                session[:error] = "file already shared with that user"
                redirect("/error")
            end
        end
    end
    rename_file(file_id, old_filename, filename)
    update_file_in_db(file_id, filename, public_status, folder_id)
    redirect("#{session[:last_route]}")
end

# Attempts to unshare a file with a user
# 
# @param [Integer] :file_id, the id of the file being unshared
# @param [Integer] :user_id, the id of the user losing access to the file
#
# @see Model#unshare_file_in_db
post("/files/:file_id/unshare/:user_id") do
    file_id = params[:file_id]
    user_id = params[:user_id]
    unshare_file_in_db(file_id, user_id)
    redirect("#{session[:last_route]}")
end

# Displays a form to create a new folder
#
get("/folders/new") do
    slim(:"folders/create")
end

# Attempts to create a folder
#
# @param [String] folder_name, the name of the folder being created
# 
# @see Model#create_folder
post("/folders/create") do
    folder_name = params[:folder_name]
    create_folder(folder_name, session[:user_id])
    redirect("#{session[:last_route]}")
end

# Attempts to delete a folder
#
# @param [Integer] folder_id, the id of the folder being deleted
#
# @see Model#delete_folder
post("/folders/:folder_id/delete") do
    folder_id = params[:folder_id]
    delete_folder(folder_id)
    redirect("/folders")
end

# Displays a form to choose a folder
#
# @see Model#get_all_folderdata_for_user_id
get("/folders") do
    folders = get_all_folderdata_for_user_id(session[:user_id])
    p folders
    slim(:"folders/select", locals:{folders: folders})
end

# Attempts to select a folder
#
# @param [Integer] folder_id, the id of the selected folder
post("/folders/select") do
    folder_id = params[:folder]
    redirect("/folders/#{folder_id}")
end

# Displays the files in the folder and a form to select a different folder and delete the current folder
#
# @param [Integer] :folder_id, the id of the selected folder
#
# @see Model#get_all_folderdata_for_user_id
# @see Model#get_all_files_in_folder
# @see Model#get_all_folderdata_for_folder_id
get("/folders/:folder_id") do
    folders = get_all_folderdata_for_user_id(session[:user_id])
    folder_id = params[:folder_id]
    files = get_all_files_in_folder(folder_id)
    current_folder = get_all_folderdata_for_folder_id(folder_id).first
    slim(:"folders/show", locals:{files: files, current_folder: current_folder, folders: folders})
end


