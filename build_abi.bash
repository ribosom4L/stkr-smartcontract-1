#!/bin/bash
json_files=$(find ./build/contracts -type f -name "*.json")
mkdir -p ./json_abi
for json_file in ${json_files}
do
    contract_name=$(cat ${json_file} | jq -r '.contractName')
    abi_file=$(echo "./json_abi/${contract_name}.json")
    cat ${json_file} | jq -r '.abi' > "${abi_file}"
    file_size=$(stat -c %s ${abi_file})
    if [[ "${file_size}" -lt "4" ]]; then
        rm ${abi_file}
    fi
done
