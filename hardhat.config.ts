import '@nomiclabs/hardhat-ethers';
import '@nomiclabs/hardhat-etherscan';
import '@nomiclabs/hardhat-waffle';
import '@typechain/hardhat';

import chai from 'chai';
import { solidity } from 'ethereum-waffle';
import 'hardhat-gas-reporter';
import { HardhatUserConfig } from 'hardhat/config';
import { DefaultBlockNumber } from './src/utils/no-deps-constants';

chai.use(solidity);
require('dotenv').config();

const infuraApiKey = process.env.INFURA_API_KEY;
if (!infuraApiKey) {
  throw new Error('No INFURA_API_KEY provided!');
}

export const config: HardhatUserConfig = {
  defaultNetwork: 'hardhat',
  networks: {
    hardhat: {
      allowUnlimitedContractSize: true,
      forking: {
        url: `https://arbitrum-mainnet.infura.io/v3/${infuraApiKey}`,
        blockNumber: DefaultBlockNumber,
      },
    },
    arbitrum: {
      url: `https://arbitrum-mainnet.infura.io/v3/${infuraApiKey}`,
      accounts: process.env.DEPLOYER_PRIVATE_KEY ? [process.env.DEPLOYER_PRIVATE_KEY] : [],
    },
  },
  solidity: {
    compilers: [
      {
        version: '0.5.16',
        settings: {
          optimizer: {
            enabled: true,
            runs: 10000,
          },
        },
      },
    ],
  },
  mocha: {
    timeout: 2000000,
  },
  typechain: {
    outDir: 'src/types',
    target: 'ethers-v5',
    alwaysGenerateOverloads: false,
    externalArtifacts: ['externalArtifacts/*.json'],
  },
  etherscan: {
    apiKey: {
      arbitrumOne: process.env.ETHERSCAN_API_KEY,
    },
  },
};

// noinspection JSUnusedGlobalSymbols
export default config;
