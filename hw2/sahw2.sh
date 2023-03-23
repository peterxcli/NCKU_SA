#!/usr/local/bin/bash

# Help message function
usage() {
  echo -n -e "\nUsage: sahw2.sh {--sha256 hashes ... | --md5 hashes ...} -i files ...\n\n--sha256: SHA256 hashes to validate input files.\n--md5: MD5 hashes to validate input files.\n-i: Input files.\n"
}

# Check if no arguments are provided
if [[ $# -eq 0 ]]; then
  usage
  exit 1
fi

# Parse command-line options
md5=()
sha256=()
input_files=()
while [[ $# -gt 0 ]]; do
  case "$1" in
  -h)
    usage
    exit 0
    ;;
  --md5)
    shift
    while [[ $# -gt 0 ]] && ! [[ $1 == -* ]]; do
      md5+=("$1")
      shift
    done
    ;;
  --sha256)
    shift
    while [[ $# -gt 0 ]] && ! [[ $1 == -* ]]; do
      sha256+=("$1")
      shift
    done
    ;;
  -i)
    shift
    while [[ $# -gt 0 ]] && ! [[ $1 == -* ]]; do
      input_files+=("$1")
      shift
    done
    ;;
  *)
    echo >&2 "Error: Invalid arguments."
    usage
    exit 1
    ;;
  esac
done

# Check if only one type of hash function is provided
if [[ ${#md5[@]} -gt 0 ]] && [[ ${#sha256[@]} -gt 0 ]]; then
  echo >&2 "Error: Only one type of hash function is allowed."
  exit 1
fi

# Check if the number of hashes matches the number of input files
if [[ ${#md5[@]} -gt 0 ]] && [[ ${#md5[@]} -ne ${#input_files[@]} ]]; then
  echo >&2 "Error: Invalid values."
  exit 1
elif [[ ${#sha256[@]} -gt 0 ]] && [[ ${#sha256[@]} -ne ${#input_files[@]} ]]; then
  echo >&2 "Error: Invalid values."
  exit 1
fi

# Validate input files with MD5 hashes
if [[ ${#md5[@]} -gt 0 ]]; then
  for ((i = 0; i < ${#input_files[@]}; i++)); do
    _md5=($(md5sum ${input_files[$i]}))
    if ! [ "$_md5" = "${md5[$i]}" ]; then
      echo >&2 "Error: Invalid checksum."
      exit 1
    fi
  done
fi

# Validate input files with SHA256 hashes
if [[ ${#sha256[@]} -gt 0 ]]; then
  for ((i = 0; i < ${#input_files[@]}; i++)); do
    _sha256=($(sha256sum ${input_files[$i]}))
    if ! [ "$_sha256" = "${sha256[$i]}" ]; then
      echo >&2 "Error: Invalid checksum."
      exit 1
    fi
  done
fi

# Parse input files
usernames=()
passwords=()
shells=()
groups=()
for input_file in "${input_files[@]}"; do
  # Determine file format
  if grep -q '{' "$input_file"; then
    # JSON file
    length=($(jq -r '. | length' data.json))
    for (( i=0; i<length; i++ )); do
      usernames+=($(jq -r ".[$i].username" "$input_file"))
      passwords+=($(jq -r ".[$i].password" "$input_file"))
      shells+=($(jq -r ".[$i].shell" "$input_file"))
      groups+=($(jq -r ".[$i].groups | join(\",\")" "$input_file"))
    done
  else
    is_csv=0
    if head -n 1 "$input_file" | awk -F, '{ if (NF < 2) exit 1 }' >/dev/null && tail -n +2 "$input_file" | awk -F, '{ if (NF < 2) exit 1 }' >/dev/null ; then
      is_csv=1
    fi
    if [ $is_csv -eq 0 ] ; then
      echo >&2 "Error: Invalid file format."
      exit 1
    fi
    # CSV file
    usernames+=($(awk -F ',' '{print $1}' "$input_file" | tail -n +2))
    passwords+=($(awk -F ',' '{print $2}' "$input_file" | tail -n +2))
    shells+=($(awk -F ',' '{print $3}' "$input_file" | tail -n +2))
    groups+=($(awk -F ',' '{print $4}' "$input_file" | tail -n +2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr ' ' ','))
  fi
done

# Determine which users need to be created
create_usernames=()
create_passwords=()
create_shells=()
create_groups=()
for (( i=0; i<${#usernames[@]}; i++ )); do
  username="${usernames[$i]}"
  password="${passwords[$i]}"
  shell="${shells[$i]}"
  group="${groups[$i]}"
  if ! id "$username" &>/dev/null; then
    # User does not exist
    create_usernames+=("$username")
    create_passwords+=("$password")
    create_shells+=("$shell")
    create_groups+=("$group")
  else
    # User already exists
    echo "Warning: user $username already exists."
  fi
done

# Prompt the user whether to continue or not
if [[ ${#create_usernames[@]} -eq 0 ]]; then
  echo "No new users to create."
  exit 0
fi
echo "This script will create the following user(s): ${create_usernames[*]}"
read -p "Do you want to continue? [y/n]: " choice
case "$choice" in
  y|Y )
    for (( i=0; i<${#create_usernames[@]}; i++ )); do
      username="${create_usernames[$i]}"
      password="${create_passwords[$i]}"
      shell="${create_shells[$i]}"
      group="${create_groups[$i]}"
      echo "${username} 's group: ${group}"
      # Create user
      sudo pw useradd "$username" -m -s "$shell" -e 0
      echo "$password" | sudo pw mod user "$username" -h 0
      for group in $(echo "$group" | tr ',' '\n' | awk '{$1=$1};1'); do
        # echo "$username, $group "
        if ! getent group "$group" &>/dev/null; then
          sudo pw groupadd "$group"
        fi
        sudo pw groupmod "$group" -m "$username"
      done
    done
    exit 0
    ;;
  n|N )
    echo "User chose not to continue."
    exit 0
    ;;
  * )
    echo "Invalid choice."
    exit 1
    ;;
esac