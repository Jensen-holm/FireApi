#! /bin/bash

git clone https://github.com/Jensen-holm/FireApi.git

cd FireApi

rm -rf .git .gitignore test

rm -f install.sh

cd FireApi && mv * ..

cd .. && rm -rf FireApi examples

cd ../..

mojo package FireApi -o FireApi.📦

mkdir packages && mv FireApi.📦 packages
