#!/bin/bash

# To check if file name argument is present
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <user_file>"
    exit 1
fi

# Assign the user file argument supplied to a variable
USER_FILE="$1"

# Check if the user file exists
if [ ! -f "$USER_FILE" ]; then
    echo "Error: File $USER_FILE does not exist."
    exit 1
fi

# Assign log and password path to variable
LOG_FILE="/var/log/user_management.log"
PASSWORD_DIR="/var/secure"
PASSWORD_FILE="$PASSWORD_DIR/user_passwords.csv"

# Create log file if not exit
touch $LOG_FILE

# Check password directory if exist, and if not, create one with only owner read access.
if [ ! -d "$PASSWORD_DIR" ]; then
    mkdir -p "$PASSWORD_DIR"
    chmod 700 "$PASSWORD_DIR"
fi

# If the password file doesn't exist, create it and add the header
if [ ! -f "$PASSWORD_FILE" ]; then
    echo "username,password" >> $PASSWORD_FILE
fi
chmod 600 $PASSWORD_FILE

# Create a logging function for the process execution
log_action() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> $LOG_FILE
}

# Create users and groups from the user file supply
while IFS=';' read -r username groups; do

    # Remove whitespace to create unique username and group
    username=$(echo "$username" | xargs)
    groups=$(echo "$groups" | xargs)
    
    # Check if user already exists
    if id -u "$username" >/dev/null 2>&1; then
        log_action "User $username already exists."
        continue
    fi
    
    # Create personal group
    if ! getent group "$username" >/dev/null 2>&1; then
        groupadd "$username"
    fi
    
    # Create user with personal group
    useradd -m -g "$username" -s /bin/bash "$username"
    
    # Set up home directory permissions
    chmod 700 /home/"$username"
    chown "$username:$username" /home/"$username"
    
    # Generate random password
    password=$(openssl rand -base64 12)
    
    # Set password for user
    echo "$username:$password" | chpasswd
    
    # Save password securely in CSV format
    echo "$username,$password" >> $PASSWORD_FILE
    
    # Add user to additional groups if specified
    if [ -n "$groups" ]; then
        IFS=',' read -r -a group_array <<< "$groups"
        for group in "${group_array[@]}"; do
            group=$(echo "$group" | xargs)
            if ! getent group "$group" >/dev/null 2>&1; then
                groupadd "$group"
            fi
            usermod -aG "$group" "$username"
        done
    fi
    
    log_action "User $username created with groups: $username, $groups"
done < $USER_FILE

log_action "User creation process completed."
