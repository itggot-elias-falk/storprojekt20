require "sqlite3"
require "bcrypt"

$db = SQLite3::Database.new("db/cloud_db.db")
$db.results_as_hash = true


# Searches for a matching email and password
#
# @param [String] email, the email
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

# Retrieves user data for a given email
#
# @param [String] email, the email in which it will try to match.
#
# @return [Hash]
#   * :user_id [Integer] the id of the user with the matching email
#   * :username [String] the username of the user with the matching email
#   * :rank [Integer] the rank of the user with the matching email
def get_user_data(email)
    user_id = $db.execute("SELECT user_id FROM users WHERE email = ?", email)[0]["user_id"]
    username = $db.execute("SELECT username FROM users WHERE email = ?", email)[0]["username"]
    rank = $db.execute("SELECT rank FROM users WHERE email = ?", email)[0]["rank"].to_i

    return {user_id: user_id, username: username, rank: rank}
end


# Searches for a specific email in the users table to see if it exists
#
# @param [String] email the email which it tries to find
# 
# @return [Boolean]
def email_exist(email)
    if $db.execute("SELECT email from users WHERE email = ?", email) != []
        return true
    else
        return false
    end
end

# Searches for a specific username in the users table to see if it exists
# 
# @param [String] userame the username which it tries to find
#
# @return [Boolean]
def username_exist(username)
    if $db.execute("SELECT username_downcase from users WHERE username_downcase = ?", username.downcase) != []
        return true
    else
        return false
    end
end


# Attempts to create a new row in the users table
# 
# @param [String] email the users email
# @param [String] username the users username
# @param [String] password_digest the hashed password for the user
# @param [Integer] rank the rank of the user
# @param [String] username_downcase the downcased version of the username
def register_user(email, username, password_digest, rank, username_downcase)
    $db.execute("INSERT INTO users (email, username, password_digest, rank, username_downcase) VALUES (?, ?, ?, ?, ?)", email, username, password_digest, rank, username_downcase)
end

# Attempts to retrieve all files with a public status set to 1
#
# @return [Array]
def get_all_public_files()
    return $db.execute("SELECT * 
        FROM files 
        INNER JOIN users ON files.owner_id = users.user_id 
        WHERE public_status = ?", 1)
end

# Attempts to fetch the username for a given user_id
#
# @param [Integer] user_id the id of the user
# 
# @return [String]
def get_username_for_id(user_id)
    return $db.execute("SELECT username FROM users WHERE user_id = ?", user_id)[0]["username"]
end


# Attempts to get all folder data for a user
#
# @param [Integer] user_id the id of the user
#
# return [Array]
def get_all_folderdata_for_user_id(user_id)
    return $db.execute("SELECT * FROM folders WHERE owner_id = ?", user_id)
end


# Attempts to find an already existing filename owned by the user
#
# @param [String] file_name the name of the file
# @param [Integer] owner_id the id of the user
#
# @return [Boolean]
def file_name_exist(file_name, owner_id)
    if $db.execute("SELECT file_name FROM files WHERE file_name = ? AND owner_id = ?", file_name, owner_id) == []
        return false
    else
        return true
    end
end

# Attempts to create a new row in files
# 
# @param [Integer] owner_id the id of the user owning the file
# @param [String] file_name the name of the file
# @param [String] upload_date the time of which the file was uploaded
# @param [String] last_access_date the time of which the last download happened
# @param [String] file_type the file type
# @param [Integer] file_size the size of the file (in bits)
# @param [Integer] folder_id the id of the files's folder
# @param [Integer] public_status the files's public status
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

# Gets the id of a file
#
# @param [String] file_name the name of the file
# @param [Integer] owner_id the id of the owner
# 
# @return [Integer]
def get_single_file_id(file_name, owner_id)
    return $db.execute("SELECT file_id FROM files WHERE owner_id = ? AND file_name = ?", owner_id, file_name)[0]["file_id"]
end

# Attempts to update a column (file_size) in a row (file_id) in files
#
# @param [Integer] file_id the files's id
# @param [Integer] file_size the new size of the file
def update_file_size(file_id, file_size)
    $db.execute("UPDATE files SET file_size = ? WHERE file_id = ?", file_size, file_id)
end

# Attempts to update a column (last_access_date) in a row (file_id) in files
#
# @param [Integer] file_id the files's id
# @param [String] time the last time the file was downloaded
def update_last_access(file_id, time)
    $db.execute("UPDATE files SET last_access_date = ? WHERE file_id = ?", time, file_id)
end

# Gets all file data for a file_id
#
# @param [Integer] file_id the id of the file
#
# @return [Hash]
def get_file_data(file_id)
    return $db.execute("SELECT * FROM files WHERE file_id = ?", file_id).first
end

# Attempts to delete a row from files
#
# @param [Integer] file_id the id of the file
def delete_file_from_db(file_id)
    $db.execute("DELETE FROM files WHERE file_id = ?", file_id)
end

# Gets the user id for a given username
#
# @param [Integer] user_id the id of the user
#
# @return [String]
# @return [Boolean] if there is no user_id
def get_user_id_for_username(username)
    user_id = $db.execute("SELECT user_id FROM users WHERE username = ?", username)
    if user_id != []
        return user_id.first["user_id"]
    else
        return false
    end
end

# Gets all the files a user owns
#
# @param [Integer] user_id the id of the user
# 
# @return [Array]
def get_all_owned_files(user_id)
    return $db.execute("SELECT * FROM files WHERE owner_id = ?", user_id)
end

# Gets all the user ids with access to a file
# 
# @param [Integer] file_id the id of the file
#
# @return [Array]
def get_users_with_access(file_id)
    return $db.execute("SELECT user_id FROM shared_files WHERE file_id = ?", file_id)
end

# Attempts to create a new row in shared_files
# 
# @param [Integer] file_id the id of the file being shared
# @param [Integer] user_id the id of the user being granted access
def share_file_with_user(user_id, file_id)
    $db.execute("INSERT INTO shared_files (user_id, file_id) VALUES (?, ?)", user_id, file_id)
end

# Attempts to update a row in files
# 
# @param [Integer] file_id the id of the file being updated
# @param [Integer] filename the name of the file
# @param [Integer] public_status the public status of the file
# @param [String] folder_id the id of the files's folder
def update_file_in_db(file_id, filename, public_status, folder_id)
    $db.execute("UPDATE files SET file_name = ?, public_status = ?, folder_id = ? WHERE file_id = ?", filename, public_status, folder_id, file_id)
end


# Gets all the files shared with a user
#
# @param [Integer] user_id the id of the user
#
# @return [Array]
def get_all_shared_files_for_user(user_id)
    return $db.execute("SELECT * 
        FROM files 
        INNER JOIN shared_files ON files.file_id = shared_files.file_id
        INNER JOIN users ON files.owner_id = users.user_id
        WHERE shared_files.user_id = ?", user_id)
end

def get_all_file_data(file_id)
    return $db.execute("SELECT files.*, users.username
        FROM files 
        INNER JOIN users ON files.owner_id = users.user_id 
        WHERE file_id = ?", file_id)
end

# Searches for a matching user_id and file_id
#
# @param [Integer] user_id the id of the user
# @param [Integer] file_id the id of the file
#
# @return [Boolean]
def already_shared(user_id, file_id)
    if $db.execute("SELECT * FROM shared_files WHERE file_id = ? AND user_id = ?", file_id, user_id) != []
        return true
    end
    return false
end

# Creates a new row in folders
# 
# @param [String] folder_name the name of the folder
# @param [Integer] user_id the id of the owner of the folder
def create_folder(folder_name, user_id)
    $db.execute("INSERT INTO folders (folder_name, owner_id) VALUES (?,?)", folder_name, user_id)
end

# Deletes a row in folders
#
# @param [Integer] folder_id the id of the folder being deleted
def delete_folder(folder_id)
    $db.execute("DELETE FROM folders WHERE folder_id = ?", folder_id)
end

# Gets all the user data for a given user id
# 
# @param [Integer] user_id the id of the user
#
# @return [Array]
def get_all_user_data(user_id)
    return $db.execute("SELECT * FROM users WHERE user_id = ?", user_id)
end


# Deletes a row in shared_files
#
# @param [Integer] user_id the id of the user being removed access
# @param [Integer] file_id the id of the file being unshared
def unshare_file_in_db(file_id, user_id)
    $db.execute("DELETE FROM shared_files WHERE file_id = ? AND user_id = ?", file_id, user_id)
end

# Gets all the files which are in a folder
#
# @param [Integer] folder_id the id of the folder
#
# @return [Array]
def get_all_files_in_folder(folder_id)
    return $db.execute("SELECT * FROM files WHERE folder_id = ?", folder_id)
end


# Gets all the folder data for a folder id
#
# @param [Integer] folder_id the id of the folder
#
# @return [Array]
def get_all_folderdata_for_folder_id(folder_id)
    return $db.execute("SELECT * FROM folders WHERE folder_id = ?", folder_id)
end


# Searches for a matching folder_id and user_id
#
# @param [Integer] folder_id the id of the folder
# @param [Integer] user_id the id of the user
#
# @return [Boolean]
def has_access_to_folder(folder_id, user_id)
    if get_all_user_data(user_id).first["rank"] == 1
        return true
    end
    owner_id = $db.execute("SELECT owner_id FROM folders WHERE folder_id = ?", folder_id).first["owner_id"]
    if owner_id == user_id
        return true
    else
        return false
    end
end

# Searches for a matching file_id and user_id in files and shared_files
#
# @param [Integer] file_id the id of the file
# @param [Integer] user_id the id of the user
#
# @return [Boolean]
def has_access_to_file(file_id, user_id)
    if get_all_user_data(user_id).first["rank"] == 1
        return true
    end

    owner_id = $db.execute("SELECT owner_id FROM files WHERE file_id = ?", file_id).first["owner_id"]
    if owner_id == user_id
        return true
    end
    shared_users = $db.execute("SELECT user_id FROM shared_files WHERE file_id = ?", file_id)
    shared_users.each do |user|
        if user["user_id"] == user_id
            return true
        end
    end
    return false
end


# Gets all data from files
#
# @return [Array]
def get_all_files()
    return $db.execute("SELECT users.username, files.* 
        FROM files 
        INNER JOIN users ON files.owner_id = users.user_id")
end