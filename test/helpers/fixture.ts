import { network } from "hardhat";

export async function getEthers() {
  return (await network.connect()).ethers;
}

export async function deploySystem() {
  const ethers = await getEthers();
  const [owner, user1, user2, attacker] = await ethers.getSigners();

  // Deploy MyStableCoin
  const coin = await ethers.deployContract("MyStableCoin");
  await coin.waitForDeployment();

  // Deploy Collateral (ERC20Mock con 6 decimales)
  const collateral = await ethers.deployContract("ERC20Mock", ["USDC Test", "USDC", 6]);
  await collateral.waitForDeployment();

  // Deploy Vault (este setea el vault dentro del constructor)
  const vault = await ethers.deployContract("StableCoinVault", [coin.target, collateral.target]);
  await vault.waitForDeployment();

  return { ethers, owner, user1, user2, attacker, coin, collateral, vault };
}
