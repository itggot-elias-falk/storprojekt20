require "sqlite3"
require "bcrypt"

$db = SQLite3::Database.new("db/cloud_db.db")
$db.results_as_hash = true

def validate_password(email, password)
    password_for_email = $db.execute("SELECT password_digest FROM users WHERE email = ?", email)[0]["password_digest"]
    p "validating password"
    if BCrypt::Password.new(password_for_email) == password
        p "password match"
        return true
    else
        p "password not match"
        return false
    end
end

def get_user_data(email)
    user_id = $db.execute("SELECT user_id FROM users WHERE email = ?", email)[0]["user_id"]
    username = $db.execute("SELECT username FROM users WHERE email = ?", email)[0]["username"]
    rank = $db.execute("SELECT rank FROM users WHERE email = ?", email)[0]["rank"].to_i

    return {user_id: user_id, username: username, rank: rank}
end

def email_exist(email)
    if $db.execute("SELECT email from users WHERE email = ?", email) != []
        return true
    else
        return false
    end
end

def username_exist(username)
    if $db.execute("SELECT username_downcase from users WHERE username_downcase = ?", username.downcase) != []
        return true
    else
        return false
    end
end

def register_user(email, username, password_digest, rank, username_downcase)
    $db.execute("INSERT INTO users (email, username, password_digest, rank, username_downcase) VALUES (?, ?, ?, ?, ?)", email, username, password_digest, rank, username_downcase)
end

def get_all_public_files()
    return $db.execute("SELECT * FROM files WHERE public_status = ?", 1)
end

def get_username_for_id(user_id)
    return $db.execute("SELECT username FROM users WHERE user_id = ?", user_id)[0]["username"]
end

def get_all_folderdata_for_user_id(user_id)
    return $db.execute("SELECT * FROM folders WHERE owner_id = ?", user_id)
end

def get_folder_id_for_folder_name(folder_name)
    return $db.execute("SELECT folder_id FROM folders WHERE folder_name = ?", folder_name).first["folder_id"]
end

def file_name_exist(file_name, owner_id)
    if $db.execute("SELECT file_name FROM files WHERE file_name = ? AND owner_id = ?", file_name, owner_id) == []
        return false
    else
        return true
    end
end

def insert_file_into_db(owner_id, file_name, upload_date, last_access_date, file_type, file_size, folder_id, public_status)
    p owner_id, file_name, upload_date, last_access_date, file_type, file_size, folder_id, public_status
    $db.execute("INSERT INTO files (owner_id,file_name,upload_date,last_access_date, file_type,file_size,folder_id,public_status) VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        owner_id,
        file_name,
        upload_date,
        last_access_date,
        file_type,
        file_size,
        folder_id,
        public_status)
end

def get_single_file_id(file_name, owner_id)
    return $db.execute("SELECT file_id FROM files WHERE owner_id = ? AND file_name = ?", owner_id, file_name)[0]["file_id"]
end

def update_file_size(file_id, file_size)
    $db.execute("UPDATE files SET file_size = ? WHERE file_id = ?", file_size, file_id)
end

def update_last_access(file_id, time)
    $db.execute("UPDATE files SET last_access_date = ? WHERE file_id = ?", time, file_id)
end

def get_file_data(file_id)
    return $db.execute("SELECT * FROM files WHERE file_id = ?", file_id).first
end

def delete_file(file_id)
    $db.execute("DELETE FROM files WHERE file_id = ?", file_id)
    $db.execute("DELETE FROM shared_files WHERE file_id = ?", file_id)
end

def get_user_id_for_username(username)
    return $db.execute("SELECT user_id FROM users WHERE username = ?", username).first["user_id"]
end

def create_file_access(file_id, user_id)
    $db.execute("INSERT INTO shared_files (file_id, user_id) VALUES (?,?)", file_id, user_id)
end

def get_all_owned_files(user_id)
    return $db.execute("SELECT * FROM files WHERE owner_id = ?", user_id)
end

def get_users_with_access(file_id)
    return $db.execute("SELECT user_id FROM shared_files WHERE file_id = ?", file_id)
end

def user_id_to_username(user_id)
    username = $db.execute("SELECT username FROM users WHERE user_id = ?", user_id)[0]["username"]
    return username
end

def share_file_with_user(user_id, file_id)
    $db.execute("INSERT INTO shared_files (user_id, file_id) VALUES (?, ?)", user_id, file_id)
end

def update_file(file_id, filename, public_status, folder_id)
    $db.execute("UPDATE files SET file_name = ?, public_status = ?, folder_id = ? WHERE file_id = ?", filename, public_status, folder_id, file_id)
end

def get_all_shared_files_id(user_id)

    return $db.execute("SELECT file_id FROM shared_files WHERE user_id = ?", user_id)
end

def get_all_file_data(file_id)
    return $db.execute("SELECT * FROM files WHERE file_id = ?", file_id)
end

def already_shared(user_id, file_id)
    if $db.execute("SELECT * FROM shared_files WHERE file_id = ? AND user_id = ?", file_id, user_id) != []
        return true
    end
    return false
end
