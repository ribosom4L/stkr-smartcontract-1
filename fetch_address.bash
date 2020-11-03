#!/bin/bash


echo "{" >> addresses.json
json_files=$(find ./build/contracts -type f -name "*.json")
for json_file in ${json_files}
do
    contract_name=$(cat ${json_file} | jq -r '.contractName')
    address=$(cat ${json_file} | jq -r '.networks."5".address')
    if [[ ! ${address} -eq 'null' ]]; then
        echo "  \"$contract_name\": \"$address\"," >> addresses.json
    fi
done
echo "}" >> addresses.json