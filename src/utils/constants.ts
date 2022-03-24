import { BaseContract, ethers } from 'ethers';
import {
  ICrvRewardNotifier,
  ICrvRewardNotifier__factory,
  IERC20,
  IERC20__factory,
  IEursUsdPool,
  IEursUsdPool__factory,
  IGauge,
  IGauge__factory,
  IRenWbtcPool,
  IRenWbtcPool__factory,
  ITriCryptoPool,
  ITriCryptoPool__factory,
  ITwoPool,
  ITwoPool__factory,
  IUniswapV2Router02,
  IUniswapV2Router02__factory,
  IUniswapV3Router,
  IUniswapV3Router__factory,
  IWETH,
  IWETH__factory,
  VaultV2,
  VaultV2__factory,
  VaultV2Payable,
  VaultV2Payable__factory,
} from '../types';

// ************************* External Contract Addresses *************************

export const CRV = new BaseContract(
  '0x11cDb42B0EB46D95f990BeDD4695A6e3fA034978',
  IERC20__factory.createInterface(),
) as IERC20;

export const CRV_EURS_USD_TOKEN = new BaseContract(
  '0x3dFe1324A0ee9d86337d06aEB829dEb4528DB9CA',
  IERC20__factory.createInterface(),
) as IERC20;

export const CRV_EURS_USD_POOL = new BaseContract(
  '0xA827a652Ead76c6B0b3D19dba05452E06e25c27e',
  IEursUsdPool__factory.createInterface(),
) as IEursUsdPool;

export const CRV_EURS_USD_POOL_GAUGE = new BaseContract(
  '0x37C7ef6B0E23C9bd9B620A6daBbFEC13CE30D824',
  IGauge__factory.createInterface(),
) as IGauge;

export const CRV_REN_WBTC_POOL = new BaseContract(
  '0x3E01dD8a5E1fb3481F0F589056b428Fc308AF0Fb',
  IRenWbtcPool__factory.createInterface(),
) as IRenWbtcPool;

// address is indeed the same as REN_WBTC_POOL
export const CRV_REN_WBTC_TOKEN = new BaseContract(
  '0x3E01dD8a5E1fb3481F0F589056b428Fc308AF0Fb',
  IERC20__factory.createInterface(),
) as IERC20;

export const CRV_REN_WBTC_POOL_GAUGE = new BaseContract(
  '0xC2b1DF84112619D190193E48148000e3990Bf627',
  IGauge__factory.createInterface(),
) as IGauge;

export const CRV_REWARD_NOTIFIER = new BaseContract(
  '0x9044E12fB1732f88ed0c93cfa5E9bB9bD2990cE5',
  ICrvRewardNotifier__factory.createInterface(),
) as ICrvRewardNotifier;

export const CRV_TRI_CRYPTO_TOKEN = new BaseContract(
  '0x8e0B8c8BB9db49a46697F3a5Bb8A308e744821D2',
  IERC20__factory.createInterface(),
) as IERC20;

export const CRV_TRI_CRYPTO_GAUGE = new BaseContract(
  '0x97E2768e8E73511cA874545DC5Ff8067eB19B787',
  IGauge__factory.createInterface(),
) as IGauge;

export const CRV_TRI_CRYPTO_POOL = new BaseContract(
  '0x960ea3e3C7FB317332d990873d354E18d7645590',
  ITriCryptoPool__factory.createInterface(),
) as ITriCryptoPool;

export const CRV_TWO_POOL = new BaseContract(
  '0x7f90122BF0700F9E7e1F688fe926940E8839F353',
  ITwoPool__factory.createInterface(),
) as ITwoPool;

// address is the same as TWO_POOL
export const CRV_TWO_POOL_TOKEN = new BaseContract(
  '0x7f90122BF0700F9E7e1F688fe926940E8839F353',
  IERC20__factory.createInterface(),
) as IERC20;

export const CRV_TWO_POOL_GAUGE = new BaseContract(
  '0xbF7E49483881C76487b0989CD7d9A8239B20CA41',
  IGauge__factory.createInterface(),
) as IGauge;

export const DAI = new BaseContract(
  '0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1',
  IERC20__factory.createInterface(),
) as IERC20;

export const LINK = new BaseContract(
  '0xf97f4df75117a78c1A5a0DBb814Af92458539FB4',
  IERC20__factory.createInterface(),
) as IERC20;

export const SUSHI = new BaseContract(
  '0xd4d42F0b6DEF4CE0383636770eF773390d85c61A',
  IERC20__factory.createInterface(),
) as IERC20;

export const SUSHI_ROUTER = new BaseContract(
  '0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506',
  IUniswapV2Router02__factory.createInterface(),
) as IUniswapV2Router02;

export const UNI = new BaseContract(
  '0xFa7F8980b0f1E64A2062791cc3b0871572f1F7f0',
  IERC20__factory.createInterface(),
) as IERC20;

export const UNISWAP_V3_ROUTER = new BaseContract(
  '0xE592427A0AEce92De3Edee1F18E0157C05861564',
  IUniswapV3Router__factory.createInterface(),
) as IUniswapV3Router;

export const USDC = new BaseContract(
  '0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8',
  IERC20__factory.createInterface(),
) as IERC20;

export const USDT = new BaseContract(
  '0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9',
  IERC20__factory.createInterface(),
) as IERC20;

export const WBTC = new BaseContract(
  '0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f',
  IERC20__factory.createInterface(),
) as IERC20;

export const WETH = new BaseContract(
  '0x82aF49447D8a07e3bd95BD0d56f35241523fBab1',
  IWETH__factory.createInterface(),
) as IWETH;

// ************************* General Constants *************************

export const OneEth = ethers.BigNumber.from('1000000000000000000');

// ************************* Network Addresses *************************

export const CrvDistributorAddress = '0x7EeAC6CDdbd1D0B8aF061742D41877D7F707289a';
export const CrvWhaleAddress = '0x4A65e76bE1b4e8dd6eF618277Fa55200e3F8F20a';

// ************************* Harvest Contract Addresses *************************

export const ControllerV1Address = '0xD5C5017659Af1E53b48aE9d55b02756342A7d4fF';
export const DolomiteMarginAddress = '0xb7576f7A382B8f446846EF72FEdB6C3E6D699E7e';
export const EthPayableVaultProxyAddress = '0xb695801B9D55A7818debF063e1E49D31C2761945';
export const GovernorAddress = '0xb39710a1309847363b9cBE5085E427cc2cAeE563';
export const ProfitSharingReceiverV1Address = '0x5F11EfDF4422B548007Cae9919b0b38c35fa6BE7';
export const RewardForwarderV1Address = '0x26B27e13E38FA8F8e43B8fc3Ff7C601A8aA0D032';
export const StorageAddress = '0xc1234a98617385D1a4b87274465375409f7E248f';
export const UniversalLiquidatorAddress = '0xe5dcf0eB836adb04FF58A472B6924fE941c4Fe76';
export const VaultV2ImplementationAddress = '0x89D4bcF2d1Ba622dD26830995E8A4aAcCc939F7e';
export const WethVaultProxyAddress = '0x4e1B3DE0cEe69AaD99f79D7cE10Bf243A7BD3A07';

// ************************* Harvest Contracts *************************

export const EthVaultProxy = new BaseContract(
  EthPayableVaultProxyAddress,
  VaultV2Payable__factory.createInterface(),
) as VaultV2Payable;

export const VaultV2Implementation = new BaseContract(
  VaultV2ImplementationAddress,
  VaultV2__factory.createInterface(),
) as VaultV2;

// ************************* Harvest Params *************************

export const DefaultImplementationDelay = 60 * 60 * 12; // 12 hours
