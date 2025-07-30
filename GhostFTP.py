import os
from ftp_service import FTPService
import argparse
import time

HOST_NAME = None
USER_NAME = None
PASSWORD = None
PORT = None
LOCAL_DIRECTORY = None
WITH_OK_FILE = None
LOCAL_ARCHIVE_DIRECTORY = None
REMOTE_DIRECTORY = None

parser = argparse.ArgumentParser(description="Script description")
parser.add_argument(
    "--prefix",
    type=str,
    default="",
    help="Prefix for environment variables",
)
parser.add_argument(
    "--host",
    type=str,
    default=HOST_NAME,
    nargs="?",
    const=True,
    help="Name of the SFTP server",
)
parser.add_argument(
    "--username",
    type=str,
    default=USER_NAME,
    nargs="?",
    const=True,
    help="User name to connect to FTP server",
)
parser.add_argument(
    "--password",
    type=str,
    default=PASSWORD,
    nargs="?",
    const=True,
    help="Password to connect to FTP server",
)
parser.add_argument(
    "--port",
    type=int,
    default=PORT,
    nargs="?",
    const=True,
    help="Port number to connect to FTP server",
)
parser.add_argument(
    "--local_directory",
    type=str,
    default=LOCAL_DIRECTORY,
    nargs="?",
    const=True,
    help="Path to local folder for storing recovered files",
)
parser.add_argument(
    "--with_ok_file",
    type=bool,
    default=WITH_OK_FILE,
    help="Include .ok files in file recovery",
)
parser.add_argument(
    "--remote_directory",
    type=str,
    default=REMOTE_DIRECTORY,
    nargs="?",
    const=True,
    help='Paths to the remote folder where we will store the files sent by default "./recu_ii/"',
)

args = parser.parse_args()

# Function to get environment variable with prefix
def get_env_var(var_name, default=None):
    return os.getenv(f"{args.prefix}_{var_name}", default)

# Check that host is present
if not args.host and not get_env_var("HOST"):
    print("The host name of the FTP server is mandatory.")
    exit()
# Check that username is present
if not args.username and not get_env_var("USERNAME"):
    print("The username to connect to the FTP server is mandatory.")
    exit()
# Check that password is present
if not args.password and not get_env_var("PASSWORD"):
    print("The password to connect to the SFTP server is mandatory")
    exit()
# Check that local_directory is present
if not args.local_directory and not get_env_var("LOCAL_DIRECTORY"):
    print("The path to the local folder where the files to be sent are stored is mandatory.")
    exit()

if args.host:
    HOST_NAME = args.host
else:
    HOST_NAME = get_env_var("HOST")

if args.username:
    USER_NAME = args.username
else:
    USER_NAME = get_env_var("USERNAME")

if args.password:
    PASSWORD = args.password
else:
    PASSWORD = get_env_var("PASSWORD")

if args.port:
    PORT = args.port
else:
    PORT = int(get_env_var("PORT"))

if args.local_directory:
    LOCAL_DIRECTORY = args.local_directory
else:
    LOCAL_DIRECTORY = get_env_var("LOCAL_DIRECTORY")

if args.with_ok_file:
    WITH_OK_FILE = args.with_ok_file
else:
    WITH_OK_FILE = get_env_var("WITH_OK_FILE", False)

if args.remote_directory:
    REMOTE_DIRECTORY = args.remote_directory
else:
    REMOTE_DIRECTORY = get_env_var("REMOTE_DIRECTORY")

LOCAL_ARCHIVE_DIRECTORY = LOCAL_DIRECTORY + "/envoye/" + str(int(time.time()))

ftp = FTPService(
    host=HOST_NAME,
    port=PORT,
    identifier=USER_NAME,
    password=PASSWORD,
)

def get_all_local_files(path, ignore_paths=[]):
    all_files = []
    for root, dirs, files in os.walk(path):
        # ignore folders ignore_paths
        dirs[:] = [d for d in dirs if d not in ignore_paths]
        for file in files:
            # ignore .ok files and .gpg files
            if not file.endswith(".ok") and not file.endswith(".gpg"):
                file_path = os.path.join(root, file)
                all_files.append(file_path)
    return all_files

def send_local_files_to_ftp(with_ok_file=False):
    try:
        local_files_paths = get_all_local_files(
            LOCAL_DIRECTORY, ignore_paths=["envoye", "recu"]
        )
        # If local_files_paths is empty, stop sending files
        if not local_files_paths:
            print("No files to send.")
            return False

        # create a list of remote files from the list of local files by deleting the name of the local folder
        remote_files_paths = [
            file.replace(LOCAL_DIRECTORY + "/", REMOTE_DIRECTORY)
            for file in local_files_paths
        ]
        for local_path, remote_path in zip(local_files_paths, remote_files_paths):
            send_file(
                local_path=local_path,
                remote_path=remote_path,
                with_ok_file=with_ok_file,
            )
        return local_files_paths
    except Exception as e:
        print(f"Error sending files : {str(e)}")
        return False

# Send multiple files over FTP
def send_file(local_path, remote_path, with_ok_file=False):
    # Checks if the file exists locally
    try:
        with open(local_path, "r") as f:
            pass
    except Exception as e:
        print(f"Local file does not exist : {str(e)}")
        return False

    # Checks if remote_file_path is not just a directory
    if remote_path.endswith("/"):
        # If remote_file_path ends with /, we add the name of the local file
        remote_path += local_path.split("/")[-1]
        # Writes a message to warn that the file will be sent to the remote directory with the local file name
        print(
            f'The remote path is a directory. The file will be sent to the directory {remote_path}'
        )

    # Send file
    try:
        # Retrieves the path of the local file before encrypting it and moves it to the send folder afterwards
        original_file_path = local_path

        # Envoie le fichier sur le sftp
        ftp.send_file(local_path, remote_path)
    except Exception as e:
        print(f"Error sending file : {local_path} error: {str(e)}")
        return False

    # Moves the original file to the sent folder
    move_file_to_envoye(original_file_path)

    # If with_ok_file is True, create an .ok file
    if with_ok_file == True:
        try:
            ok_file_path = local_path
            ok_remote_path = remote_path
            if not local_path.endswith(".ok"):
                ok_file_path = local_path + ".ok"
                # Creates an .ok file
                with open(ok_file_path, "w") as f:
                    pass
            # If remote_file_path ends with .ok, it is not added
            if not remote_path.endswith(".ok"):
                ok_remote_path = remote_path + ".ok"
            # Send .ok file to ftp
            ftp.send_file(ok_file_path, ok_remote_path)
            # Moves the original file to the sent folder
            move_file_to_envoye(original_file_path)
        except Exception as e:
            print(
                f"Error sending file : {ok_file_path}, error: {str(e)}"
            )
            return False
        finally:
            # If the local .ok file exists, delete it
            if os.path.exists(ok_file_path):
                os.remove(ok_file_path)

    return original_file_path

def move_file_to_envoye(local_file_path):
    # Removes the local_directory from the file path and replaces it with send_directory
    new_file_path = local_file_path.replace(LOCAL_DIRECTORY, LOCAL_ARCHIVE_DIRECTORY)
    # Create send folder if none exists
    os.makedirs(os.path.dirname(new_file_path), exist_ok=True)
    # Moves the file to the sent folder
    os.rename(local_file_path, new_file_path)
    return new_file_path

# FTP connection
if not ftp.connect():
    exit()
else:
    print("Sending files over FTP...")
    send_local_files_to_ftp(with_ok_file=WITH_OK_FILE)
    print("Sending files over FTP complete.")
