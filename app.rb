require "sinatra"
require "slim"
require "bcrypt"
require "sqlite3"
require "fileutils"
require_relative "./model.rb"

enable :sessions

before do
    path = request.path_info
    p path
    p session[:user_id]

    if (session[:user_id] == nil || session[:user_id] == 0) && (path != "/" && path != "/register" && path != "/home" && path != "/login")
        p "redirecting"
        redirect("/")
    end
end

after do
    session[:last_route] = request.path
    p session[:last_route]
end



get("/") do
    if session[:user_id] != 0 && session[:user_id] != nil
        redirect("/home")
    end
    session[:username] = ""
    session[:email] = ""
    session[:user_id] = 0
    session[:rank] = 0
    slim(:"users/index")
end

get("/register") do
    slim(:"users/register")
end

post("/register") do
    email = params[:email].downcase
    username = params[:username]
    password = params[:password]
    confirm_password = params[:confirm_password]

    if email_exist(email)
        session[:register_username] = username
        session[:register_error] = "email"
        redirect("/register")
    end

    if username_exist(username)
        session[:register_email] = email
        session[:register_error] = "username"
        redirect("/register")
    end

    if password != confirm_password
        session[:register_email] = email
        session[:register_username] = username
        session[:register_password] = password
        session[:register_error] = "password"
        redirect("/register")
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

post("/login") do
    email = params[:email].downcase
    password = params[:password]

    p "checking email"
    if !email_exist(email)
        session[:login_error] = "email"
        redirect("/")
    end

    p "checking password"
    if !validate_password(email, password)
        session[:login_error] = "password"
        redirect("/")
    end

    p "login success"

    session[:email] = email
    user_data = get_user_data(email)
    session[:user_id] = user_data[:user_id]
    session[:username] = user_data[:username]
    session[:rank] = user_data[:rank]
    redirect("/home")
end

get("/home") do
    if session[:user_id] == nil
        redirect("/")
    end

    public_files = get_all_public_files()
    slim(:home, locals:{public_files: public_files})
end

post("/logout") do
    session.clear
    redirect("/")
end

get("/file/upload") do
    if session[:user_id] == nil
        redirect("/")
    end
    user_folders = get_all_folderdata_for_user_id(session[:user_id])
    slim(:"files/upload", locals: {user_folders: user_folders})
end

def create_file(file_id, filename, file)
    Dir.mkdir "./public/uploads/#{file_id}"
    path = "./public/uploads/#{file_id}/#{filename}"
    File.open(path, 'wb') do |f|
        f.write(file.read)
    end
end

post("/file/upload") do
    if params[:file] && params[:file][:filename]

        if params[:file_name] == ""
            filename = params[:file][:filename]
        else
            filename = params[:file_name] + "." + params[:file][:filename].split(".")[1]
        end

        file = params[:file][:tempfile]
        file_type = params[:file][:type]
        folder_name = params[:folder].chomp
        public_status = params[:public]

        if public_status == "on"
            public_status = 1
        else
            public_status = 0
        end

        if folder_name.downcase != "select folder"
            folder_id = get_folder_id_for_folder_name(folder_name)
        else
            folder_id = 0
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
    redirect("/home")
end

post("/file/download/:file_id") do
    file_id = params[:file_id]
    filename = get_file_data(file_id)["file_name"]
    time = Time.new.inspect.split(" +")[0]
    update_last_access(file_id, time)
    send_file("./public/uploads/#{file_id}/#{filename}", :filename=>filename, :type=>"application/octet-stream")
    redirect("/home")
end

post("/file/delete/:file_id") do
    file_id = params[:file_id]
    FileUtils.remove_dir("./public/uploads/#{file_id}")
    delete_file(file_id)
    redirect("#{session[:last_route]}")
end

get("/user") do
    slim(:"users/edit")
end

post("/file/share/:file_id") do
    share_username = params[:username]
    user_id = get_user_id_for_username()
    file_id = params[:file_id]
    create_file_access(file_id, user_id)
    redirect("/share")
end

get("/user_files") do
    owned_files = get_all_owned_files(session[:user_id])

    shared_files = get_all_shared_files_for_user(session[:user_id])
    p shared_files
    slim(:"files/user_files", locals: {shared_files: shared_files, owned_files: owned_files})
end

get("/user_files/:file_id") do
    file_id = params["file_id"]
    file = get_file_data(file_id)
    user_ids_with_access = get_users_with_access(file_id)
    
    usernames = []
    users_with_access = []
    if user_ids_with_access != []
        user_ids_with_access.each do |user_id|
            users_with_access << get_all_user_data(user_id["user_id"]).first
        end
    end

    user_folders = get_all_folderdata_for_user_id(session[:user_id])

    slim(:"files/edit", locals:{file_id: file_id, file: file, users_with_access: users_with_access, user_folders: user_folders})
end

post("/update_file/:file_id") do
    filename = params[:file_name]
    public_status = params[:public_status]
    share_usernames = params[:share_usernames].split(", ")
    folder_id = params[:folder]
    file_id = params[:file_id]

    if share_usernames
        share_usernames.each do |username|
            # TODO: make it work with lowercase usernames
            user_id = get_user_id_for_username(username)
            if !user_id
                session[:share_error] = "no such user exists"
            elsif user_id != [] && !already_shared(user_id, file_id)
                share_file_with_user(user_id, file_id)
            else
                session[:share_error] = "file already shared with that user"
            end
        end
    end

    update_file(file_id, filename, public_status, folder_id)
    redirect("#{session[:last_route]}")
end

get("/folders/new") do
    slim(:"folders/new")
end

post("/folders/create") do
    folder_name = params[:folder_name]
    create_folder(folder_name, session[:user_id])
    redirect("#{session[:last_route]}")
end

post("/files/:file_id/unshare/:user_id") do
    file_id = params[:file_id]
    user_id = params[:user_id]
    unshare_file(file_id, user_id)
    redirect("#{session[:last_route]}")
end

get("/folders") do
    folders = get_all_folderdata_for_user_id(session[:user_id])
    p folders
    slim(:"folders/select", locals:{folders: folders})
end

post("/folders/select") do
    folder_id = params[:folder]
    redirect("/folders/#{folder_id}")
end

get("/folders/:folder_id") do
    folders = get_all_folderdata_for_user_id(session[:user_id])
    folder_id = params[:folder_id]
    files = get_all_files_in_folder(folder_id)
    current_folder = get_all_folderdata_for_folder_id(folder_id).first
    slim(:"folders/show", locals:{files: files, current_folder: current_folder, folders: folders})
end
