#!/bin/bash

# Define the commands to execute
read -r -d '' commands << EOM
wget https://github.com/arsham/figurine/releases/download/v1.3.0/figurine_linux_amd64_v1.3.0.tar.gz
tar -xvf figurine_linux_amd64_v1.3.0.tar.gz
mv deploy/figurine /usr/local/bin/
rm -r deploy/
rm figurine_linux_amd64_v1.3.0.tar.gz
echo '#!/bin/bash' > /etc/profile.d/figurine.sh
echo 'echo ""' >> /etc/profile.d/figurine.sh
echo '/usr/local/bin/figurine -f "3d.flf" \$(hostname)' >> /etc/profile.d/figurine.sh
echo 'echo ""' >> /etc/profile.d/figurine.sh
chmod +x /etc/profile.d/figurine.sh
EOM

# Ask the user to enter the command they want to execute
command="bash -c '$commands'"

# Initialize an array to store the executed containers
executed_containers=()

# Ask if they want to execute in all containers or customize
execute_in_all=$(whiptail --yesno "Do you want to execute the command in all containers?" 10 60 --title "Execute in All" 3>&1 1>&2 2>&3)

if [ $? -eq 0 ]; then
    # Execute in all containers
    echo "Executing commands in all containers..."
    for CTID in $(pct list | awk 'NR>1 {print $1}'); do
        pct exec $CTID -- bash -c "$commands"
        NAME=$(pct list | awk -v id=$CTID '$1 == id {print $3}')
        executed_containers+=("$CTID $NAME")
    done
else
    # Get the list of LXC containers (ID and name)
    container_list=$(pct list | awk 'NR>1 {print $1, $3}')  # The container name is in the third column

    # Generate the format for whiptail (ID and container name)
    options=()
    while read -r line; do
        CTID=$(echo "$line" | awk '{print $1}')   # Extract the container ID
        NAME=$(echo "$line" | awk '{print $2}')   # Extract the container name
        options+=($CTID "$NAME" OFF)              # Add to the options array for whiptail
    done <<< "$container_list"

    # Use whiptail to select containers (checkboxes)
    selected=$(whiptail --title "Select LXC Containers" --checklist \
    "Select the containers to execute the command:" 20 60 10 \
    "${options[@]}" 3>&1 1>&2 2>&3)

    # Check if the user selected containers
    if [ $? -eq 0 ]; then
        # Remove quotes from the selection
        selected=$(echo $selected | tr -d '"')

        # Execute the command in each selected container
        for CTID in $selected; do
            echo "Executing commands in Container $CTID..."
            pct exec $CTID -- bash -c "$commands"
            NAME=$(pct list | awk -v id=$CTID '$1 == id {print $3}')
            executed_containers+=("$CTID $NAME")
        done
    else
        echo "No containers were selected."
    fi
fi

# Clear the screen
clear

# Print the summary table if there are executed containers
if [ ${#executed_containers[@]} -gt 0 ]; then
    echo "Summary of executed commands:"
    printf "%-10s %-20s\n" "Container ID" "Container Name"
    printf "%-10s %-20s\n" "------------" "--------------"
    for container in "${executed_containers[@]}"; do
        printf "%-10s %-20s\n" $(echo $container)
    done
else
    echo "No containers were selected."
fi