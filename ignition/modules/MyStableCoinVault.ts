import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("MyStableCoinVaultModule", (m) => {
  // 1️ Desplegar MyStableCoin
  const stablecoin = m.contract("MyStableCoin");

  // 2️ Desplegar ERC20Mock para simular colateral
  const collateralToken = m.contract("ERC20Mock", ["USDC Test", "USDC", 6]);

  // 3️ Desplegar Vault
  const vault = m.contract("StableCoinVault", [stablecoin, collateralToken]);


  return { stablecoin, collateralToken, vault };
});
