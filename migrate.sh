#!/bin/bash
yarn compile

yarn migrate:goerli

rm -f goerli.json
rm -f develop.json

echo "{" >> develop.json
json_files=$(find ./build/contracts -type f -name "*.json")
for json_file in ${json_files}
do
    contract_name=$(cat ${json_file} | jq -r '.contractName')
    address=$(cat ${json_file} | jq -r '.networks."5777".address')
    if [[ ! ${address} -eq 'null' ]]; then
        echo "  \"$contract_name\": \"$address\"," >> develop.json
    fi
done
echo "}" >> develop.json

echo "{" >> goerli.json
json_files=$(find ./build/contracts -type f -name "*.json")
for json_file in ${json_files}
do
    contract_name=$(cat ${json_file} | jq -r '.contractName')
    address=$(cat ${json_file} | jq -r '.networks."5777".address')
    if [[ ! ${address} -eq 'null' ]]; then
        echo "  \"$contract_name\": \"$address\"," >> goerli.json
    fi
done
echo "}" >> goerli.json