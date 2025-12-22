import { network } from "hardhat";

export async function getEthers() {
  return (await network.connect()).ethers;
}
//Cuando llegue la stablecoin, solo cambiar el nombre del contrato y args en 1 lugar.
export async function deployContract<T = any>(contractName: string, args: any[] = []) {
  const ethers = await getEthers();
  const factory = await ethers.getContractFactory(contractName);
  const contract = await factory.deploy(...args);
  await contract.waitForDeployment();
  return { ethers, contract: contract as T };
}
