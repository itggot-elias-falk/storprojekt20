require "sqlite3"
require "bcrypt"

def db()
    db = SQLite3::Database.new("db/cloud_db.db")
    db.results_as_hash = true
    return db
end

def validate_password(email, password)
    password_for_email = db.execute("SELECT password_digest FROM users WHERE email = ?", email)[0]["password_digest"]

    if BCrypt::Password.new(password_for_email) != password
        return false
    else
        return true
    end
end

def get_user_data(email)
    user_id = db.execute("SELECT user_id FROM users WHERE email = ?", email)[0]["user_id"]
    username = db.execute("SELECT username FROM users WHERE email = ?", email)[0]["username"]
    rank = db.execute("SELECT rank FROM users WHERE email = ?", email)[0]["rank"].to_i

    return {user_id: user_id, username: username, rank: rank}
end

def email_exist(email)
    if db.execute("SELECT email from users WHERE email = ?", email).exist?
        return true
    else
        return false
    end
end

def get_all_public_files()
    return db.execute("SELECT * FROM files WHERE public_status = ?", 1)
end

def get_username_for_id(user_id)
    return db.execute("SELECT username FROM users WHERE user_id = ?", user_id)
end

def get_all_folderdata_for_user_id(user_id)
    return db.execute("SELECT * FROM folders WHERE owner_id = ?", user_id)
end

def get_folder_id_for_folder_name(folder_name)
    return db.execute("SELECT folder_id FROM folders WHERE folder_name = ?", folder_name).first["folder_id"]
end

def file_name_exist(file_name, owner_id)
    if db.execute("SELECT file_name FROM files WHERE file_name = ? AND owner_id = ?", file_name, user_id).empty?
        return false
    else
        return true
    end
end

def insert_file_into_db(owner_id, file_name, upload_date, last_access_date, file_type, file_size, folder_id, public_status)
    db.execute("INSERT INTO files (owner_id,
        file_name,
        upload_date,
        last_access_date,
        file_type,
        file_size,
        folder_id,
        public_status)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        file_name,
        upload_date,
        last_access_date,
        file_type,
        file_size,
        folder_id,
        public_status)
    return db.execute("SELECT file_id FROM files WHERE owner_id = ? AND file_name = ?", session[:user_id], filename)[0]["file_id"]
    create_file(file_id, filename, file)
end

def get_single_file_id(file_name, owner_id)
    return db.execute("SELECT file_id FROM files WHERE owner_id = ? AND file_name = ?", owner_id, file_name)[0]["file_id"]
end

def update_file_size(file_id, file_size)
    db.execute("UPDATE files SET file_size = ? WHERE file_id = ?", file_size, file_id)
end

def update_last_access(file_id, time)
    db.execute("UPDATE files SET last_access_date = ? WHERE file_id = ?", time, file_id)
end

def get_file_data(file_id)
    return db.execute("SELECT * FROM files WHERE file_id = ?", file_id).first
end