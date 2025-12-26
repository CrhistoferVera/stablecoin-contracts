// [1] IMPORTANTE: Esta linea soluciona el error ts(2353)
import "@nomicfoundation/hardhat-verify";

import hardhatToolboxMochaEthersPlugin from "@nomicfoundation/hardhat-toolbox-mocha-ethers";
import { configVariable, defineConfig } from "hardhat/config";

export default defineConfig({
  plugins: [hardhatToolboxMochaEthersPlugin],

  solidity: {
    profiles: {
      default: {
        version: "0.8.28",
      },
      production: {
        version: "0.8.28",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    },
  },

  networks: {
    hardhatMainnet: {
      type: "edr-simulated",
      chainType: "l1",
    },
    hardhatOp: {
      type: "edr-simulated",
      chainType: "op",
    },
    sepolia: {
      type: "http",
      chainType: "l1",
      url: configVariable("SEPOLIA_RPC_URL"),
      accounts: [configVariable("SEPOLIA_PRIVATE_KEY")],
    },
    localhost: {
      type: "http",
      chainId: 31337,
      url: "http://127.0.0.1:8545",
    },
  },

  // [2] Ahora TypeScript reconocerá este bloque sin errores
  etherscan: {
    apiKey: configVariable("ETHERSCAN_API_KEY"),
  },
} as any);