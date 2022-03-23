pragma solidity ^0.5.16;


contract Constants {

    // ========================= Pools / Protocols =========================

    address constant internal CRV_EURS_USD_TOKEN = 0x3dFe1324A0ee9d86337d06aEB829dEb4528DB9CA;

    address constant internal CRV_EURS_USD_POOL = 0xA827a652Ead76c6B0b3D19dba05452E06e25c27e;

    address constant internal CRV_EURS_USD_GAUGE = 0x37C7ef6B0E23C9bd9B620A6daBbFEC13CE30D824;

    address constant internal CRV_REN_WBTC_POOL = 0x3E01dD8a5E1fb3481F0F589056b428Fc308AF0Fb;

    address constant internal CRV_REN_WBTC_GAUGE = 0xC2b1DF84112619D190193E48148000e3990Bf627;

    address constant internal CRV_TRI_CRYPTO_TOKEN = 0x8e0B8c8BB9db49a46697F3a5Bb8A308e744821D2;

    address constant internal CRV_TRI_CRYPTO_GAUGE = 0x97E2768e8E73511cA874545DC5Ff8067eB19B787;

    address constant internal CRV_TRI_CRYPTO_POOL = 0x960ea3e3C7FB317332d990873d354E18d7645590;

    address constant internal CRV_TWO_POOL = 0x7f90122BF0700F9E7e1F688fe926940E8839F353;

    address constant internal CRV_TWO_POOL_GAUGE = 0xbF7E49483881C76487b0989CD7d9A8239B20CA41;

    /// @notice Used as governance
    address constant public DEFAULT_MULTI_SIG_ADDRESS = 0xb39710a1309847363b9cBE5085E427cc2cAeE563;

    address constant public SUSHI_ROUTER = 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506;

    address constant public UNISWAP_V3_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

    // ========================= Tokens =========================

    address constant public CRV = 0x11cDb42B0EB46D95f990BeDD4695A6e3fA034978;

    address constant public DAI = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;

    // We can set this later once we know the address
//    address constant public FARM = 0x0000000000000000000000000000000000000000;

    address constant public LINK = 0xf97f4df75117a78c1A5a0DBb814Af92458539FB4;

    address constant public ONE_INCH = 0x0000000000000000000000000000000000000000;

    address constant public SUSHI = 0xd4d42F0b6DEF4CE0383636770eF773390d85c61A;

    address constant public UNI = 0xFa7F8980b0f1E64A2062791cc3b0871572f1F7f0;

    address constant public USDC = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;

    address constant public USDT = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;

    address constant public WBTC = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;

    address constant public WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
}
