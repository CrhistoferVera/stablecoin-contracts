import { network } from "hardhat";
import { TARGET_CONTRACT } from "./targets.js";

export async function getEthers() {
  return (await network.connect()).ethers;
}

// Deploy genérico por nombre de contrato + args
export async function deployContract<T = any>(contractName: string, args: any[] = []) {
  const ethers = await getEthers();
  const factory = await ethers.getContractFactory(contractName);
  const contract = await factory.deploy(...args);
  await contract.waitForDeployment();
  return { ethers, contract: contract as T };
}

// Deploy "objetivo": aquí se centralizan args según contrato
export async function deployTarget<T = any>() {
  // MyStableCoin no tiene args en constructor
  if (TARGET_CONTRACT === "MyStableCoin") {
    return deployContract<T>(TARGET_CONTRACT, []);
  }

  // SecurityPlayground sí requiere (admin)
  if (TARGET_CONTRACT === "SecurityPlayground") {
    const ethers = await getEthers();
    const [admin] = await ethers.getSigners();
    return deployContract<T>(TARGET_CONTRACT, [admin.address]);
  }

  // Fallback: intenta desplegar sin args
  return deployContract<T>(TARGET_CONTRACT, []);
}
