require "sinatra"
require "slim"
require "bcrypt"
require "sqlite3"
require "fileutils"

enable :sessions
db = SQLite3::Database.new("db/cloud_db.db")
db.results_as_hash = true

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
    email = params[:email]
    username = params[:username]
    password = params[:password]
    confirm_password = params[:confirm_password]

    if db.execute("SELECT email from users WHERE email = ?", email) != []
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
    email = params[:email]
    password = params[:password]

    if db.execute("SELECT email FROM users WHERE email = ?", email) == []
        session[:login_error] = "email"
        redirect("/")
    end

    password_for_email = db.execute("SELECT password_digest FROM users WHERE email = ?", email)[0]["password_digest"]

    if BCrypt::Password.new(password_for_email) != password
        session[:login_error] = "password"
        redirect("/")
    end

    session[:email] = email
    session[:user_id] = db.execute("SELECT user_id FROM users WHERE email = ?", email)[0]["user_id"]
    session[:username] = db.execute("SELECT username FROM users WHERE email = ?", email)[0]["username"]
    session[:rank] = db.execute("SELECT rank FROM users WHERE email = ?", email)[0]["rank"].to_i

    redirect("/home")
end

get("/home") do
    if session[:user_id] == nil
        redirect("/")
    end

    session[:owned_files] = db.execute("SELECT * FROM files WHERE owner_id = ?", session[:user_id])
    slim(:home)
end

post("/logout") do
    session.clear
    redirect("/")
end

get("/upload") do
    if session[:user_id] == nil
        redirect("/")
    end
    slim(:upload)
end

post("/upload") do
    if params[:file] && params[:file][:filename]
        filename = params[:file_name]
        file = params[:file][:tempfile]
        file_type = params[:file][:type]
        p file_type
        p filename

        if !db.execute("SELECT file_name FROM files WHERE file_name = ? AND owner_id = ?", filename, session[:user_id]).empty?
            redirect("/upload")
        end

        time = Time.new.inspect.split(" +")[0]
        
        db.execute("INSERT INTO files (owner_id, file_name, upload_date, last_access_date, file_type, file_size) VALUES (?, ?, ?, ?, ?, ?)", session[:user_id], filename, time, time, file_type, 0)
        file_id = db.execute("SELECT file_id FROM files WHERE owner_id = ? AND file_name = ?", session[:user_id], filename)[0]["file_id"]
        
        Dir.mkdir "./public/uploads/#{file_id}"
        path = "./public/uploads/#{file_id}/#{filename}"
        # Write file to disk
        File.open(path, 'wb') do |f|
            f.write(file.read)
        end

        file_size = File.size("./public/uploads/#{file_id}/#{filename}")
        db.execute("UPDATE files SET file_size = ? WHERE file_id = ?", file_size, file_id)
    end
    redirect("/home")
end

post("/download") do
    file_id = params[:file_id]
    filename = db.execute("SELECT file_name FROM files WHERE file_id = ?", file_id)[0]["file_name"]
    time = Time.new.inspect.split(" +")[0]

    db.execute("UPDATE files SET last_access_date = ? WHERE file_id = ?", time, file_id)
    send_file("./public/uploads/#{file_id}/#{filename}", :filename=>filename, :type=>"application/octet-stream")
    redirect("/home")
end

post("/delete") do
    file_id = params[:file_id]
    FileUtils.remove_dir("./public/uploads/#{file_id}")
    db.execute("DELETE FROM files WHERE file_id = ?", file_id)
    redirect("/home")
end

get("/user") do
    slim(:user)
end

post("/share_file") do
    share_username = params[:username]
    user_id = db.execute("SELECT user_id FROM users WHERE username = ?", share_username).first["user_id"]
    file_id = params[:file_id]
    db.execute("INSERT INTO shared_files (file_id, user_id)")
    redirect("/share")
end
