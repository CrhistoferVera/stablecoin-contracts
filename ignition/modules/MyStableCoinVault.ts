import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("MyStableCoinVaultModule", (m) => {
  // 1️ Desplegar MyStableCoin
  const stablecoin = m.contract("MyStableCoin");

  // 2️ Desplegar ERC20Mock para simular colateral
  const collateralToken = m.contract("ERC20Mock", {
    constructorArgs: ["USDC Test", "USDC", 6],
  });

  // 3️ Desplegar Vault
  const vault = m.contract("StableCoinVault", {
    constructorArgs: [stablecoin, collateralToken],
  });

  // 4️ Asignar Vault en MyStableCoin
  m.call(stablecoin, "setVault", [vault]);
  // 5️ Mint inicial para pruebas
  const owner = m.getAccount(0);
  const depositAmount = 150n * 1_000_000n; // 150 USDC
  m.call(collateralToken, "mint", [owner, depositAmount]);
  m.call(collateralToken, "approve", [vault, depositAmount]);
  m.call(vault, "mintStable", [depositAmount]);

  return { stablecoin, collateralToken, vault };
});
