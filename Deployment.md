## Deployment

For deployment, copy `.env.example` to `.env` and paste deployment private key to .env
 
```sh
yarn install
yarn test
yarn migrate --network mainnet
```

After migration, keep .openzeppelin and build folder safe
