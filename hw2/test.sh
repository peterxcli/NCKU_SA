#!/bin/bash
usernames=()
passwords=()
shells=()
groups=()

usernames+=($(awk -F ',' '{print $1}' $1 | tail -n +2))
passwords+=($(awk -F ',' '{print $2}' $1 | tail -n +2))
shells+=($(awk -F ',' '{print $3}' $1 | tail -n +2))
groups+=($(awk -F ',' '{print $4}' $1 | tail -n +2 | tr ' ' ','))

# print out the arrays by each user
for (( i=0; i<${#usernames[@]}; i++ )); do
  echo -n "Username: ${usernames[$i]}"
  echo -n ", Password: ${passwords[$i]}"
  echo -n ", Shell: ${shells[$i]}"
  echo -n ", Groups: ${groups[$i]}"
  echo ""
done