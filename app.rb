require "sinatra"
require "slim"
require "bcrypt"
require "sqlite3"
require "fileutils"
require_relative "./model.rb"

enable :sessions

# before do

#     p request.path_info

#     path = request.path_info

#     if session[:user_id] == nil || session[:user_id] == 0
#         session[:user_id]
#         if path != "/"
#             redirect("/")
#         end
#     end
# end

after do
    session[:last_route] = request.path
    p session[:last_route]
end

def user_id_to_username(user_id)
    usernames = []
    user_id.each do |id|
        usernames << db.execute("SELECT username FROM users WHERE user_id = ?", id)[0]["username"]
    end
    return usernames
end

get("/") do
    if session[:user_id] != 0 && session[:user_id] != nil
        redirect("/home")
    end
    session[:username] = ""
    session[:email] = ""
    session[:user_id] = 0
    session[:rank] = 0
    slim(:index)
end

get("/register") do
    slim(:register)
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

    if db.execute("SELECT username_downcase from users WHERE username_downcase = ?", username.downcase) != []
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
    db.execute("INSERT INTO users (email, username, password_digest, rank, username_downcase) VALUES (?, ?, ?, ?, ?)", email, username, password_digest, 0, username.downcase)
    
    session[:username] = username
    session[:email] = email
    session[:user_id] = db.execute("SELECT user_id FROM users WHERE username = ?", username)[0]["user_id"]
    session[:rank] = 0
    db.execute("INSERT INTO folders (owner_id, folder_name) VALUES (?, ?)", session[:user_id], session[:user_id])

    redirect("/home")
end

post("/login") do
    email = params[:email].downcase
    password = params[:password]

    if !validate_email(email)
        session[:login_error] = "email"
        redirect("/")
    end

    if validate_password(email, password)
        session[:login_error] = "password"
        redirect("/")
    end

    session[:email] = email

    user_data = get_user_data(email)
    session[:user_id] = user_data["user_id"]
    session[:username] = user_data["username"]
    session[:rank] = user_data["rank"]

    redirect("/home")
end

get("/home") do
    if session[:user_id] == nil
        redirect("/")
    end


    session[:public_files] = db.execute("SELECT * FROM files WHERE public_status = ?", 1)
    session[:owners] = []
    session[:public_files].each do |file|
        session[:owners] << db.execute("SELECT username FROM users WHERE user_id = ?", file["owner_id"]).first["username"]
    end
    slim(:home)
end

post("/logout") do
    session.clear
    redirect("/")
end

get("/file/upload") do
    if session[:user_id] == nil
        redirect("/")
    end
    session[:user_folders] = db.execute("SELECT folder_name FROM folders WHERE owner_id = ?", session[:user_id])
    p session[:user_folders]
    slim(:upload)
end

# def get_all_file_user_data(user_id)
#     user_data = db.execute("SELECT * FROM users WHERE user_id = ?", user_id).first
#     user_files = db.execute("SELECT * FROM files WHERE owner_id = ?", user_id).first
#     user_folders = db.execute("SELECT * FROM folders WHERE owner_id = ?", user_id).first
#     user_shared_files = db.execute("SELECT * FROM shared_files WHERE user_id = ?", user_id).first
#     all_data = {user_data: user_data, user_files: user_files, user_folders: user_folders, user_shared_files: user_shared_files}
#     p all_data
#     return all_data
# end

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
            folder_id = db.execute("SELECT folder_id FROM folders WHERE folder_name = ?", folder_name).first["folder_id"]
        else
            folder_id = 0
        end

        if !db.execute("SELECT file_name FROM files WHERE file_name = ? AND owner_id = ?", filename, session[:user_id]).empty?
            redirect("/upload")
        end

        time = Time.new.inspect.split(" +")[0]
        
        db.execute("INSERT INTO files (owner_id, file_name, upload_date, last_access_date, file_type, file_size, folder_id, public_status) VALUES (?, ?, ?, ?, ?, ?, ?, ?)", session[:user_id], filename, time, time, file_type, 0, folder_id, public_status)
        file_id = db.execute("SELECT file_id FROM files WHERE owner_id = ? AND file_name = ?", session[:user_id], filename)[0]["file_id"]

        create_file(file_id, filename, file)

        file_size = File.size("./public/uploads/#{file_id}/#{filename}")
        db.execute("UPDATE files SET file_size = ? WHERE file_id = ?", file_size, file_id)
    end
    redirect("/home")
end

post("/file/download/:file_id") do
    file_id = params[:file_id]
    filename = db.execute("SELECT file_name FROM files WHERE file_id = ?", file_id)[0]["file_name"]
    time = Time.new.inspect.split(" +")[0]
    db.execute("UPDATE files SET last_access_date = ? WHERE file_id = ?", time, file_id)
    send_file("./public/uploads/#{file_id}/#{filename}", :filename=>filename, :type=>"application/octet-stream")
    redirect("/home")
end

post("/file/delete/:file_id") do
    file_id = params[:file_id]
    FileUtils.remove_dir("./public/uploads/#{file_id}")
    db.execute("DELETE FROM files WHERE file_id = ?", file_id)
    redirect("#{session[:last_route]}")
end

get("/user") do
    slim(:user)
end

post("/file/share/:file_id") do
    share_username = params[:username]
    user_id = db.execute("SELECT user_id FROM users WHERE username = ?", share_username).first["user_id"]
    file_id = params[:file_id]
    db.execute("INSERT INTO shared_files (file_id, user_id)")
    redirect("/share")
end

get("/user_files") do
    session[:owned_files] = db.execute("SELECT * FROM files WHERE owner_id = ?", session[:user_id])
    slim(:user_files)
end

get("/user_files/:file_id") do
    session[:file_id] = params["file_id"]
    session[:file] = db.execute("SELECT * FROM files WHERE file_id = ?", session[:file_id])[0]
    user_ids_with_access = db.execute("SELECT user_id FROM shared_files WHERE file_id = ?", session[:file_id])
    usernames_with_access = user_id_to_username(user_ids_with_access)
    session[:users_with_access] = usernames_with_access.join(", ")
    slim(:edit_file)
end

post("/update_file/:file_id") do

end