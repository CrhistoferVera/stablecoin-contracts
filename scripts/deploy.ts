import { network } from "hardhat";

async function main() {
  const { ethers } = await network.connect();
  const [deployer] = await ethers.getSigners();

  console.log("Deploying with account:", deployer.address);
  console.log("Balance:", ethers.formatEther(await ethers.provider.getBalance(deployer.address)), "ETH");

  // 1. Deploy implementation
  console.log("\n--- Step 1: Deploying implementation ---");
  const Implementation = await ethers.getContractFactory("MyStableCoin");
  const implementation = await Implementation.deploy();
  await implementation.waitForDeployment();
  const implAddress = await implementation.getAddress();
  console.log("Implementation deployed at:", implAddress);

  // 2. Encode initialize call
  const initData = Implementation.interface.encodeFunctionData("initialize", [
    deployer.address,
  ]);

  // 3. Deploy ERC1967Proxy pointing to implementation
  console.log("\n--- Step 2: Deploying ERC1967 Proxy ---");
  const Proxy = await ethers.getContractFactory("MyStableCoinProxy");
  const proxy = await Proxy.deploy(implAddress, initData);
  await proxy.waitForDeployment();
  const proxyAddress = await proxy.getAddress();
  console.log("Proxy deployed at:", proxyAddress);

  // 4. Verify proxy works
  console.log("\n--- Step 3: Verifying deployment ---");
  const stablecoin = Implementation.attach(proxyAddress);
  console.log("Name:", await stablecoin.name());
  console.log("Symbol:", await stablecoin.symbol());
  console.log("Decimals:", await stablecoin.decimals());
  console.log("Version:", await stablecoin.version());
  console.log("Admin:", deployer.address);

  console.log("\n--- Deployment complete ---");
  console.log("Proxy (use this address):", proxyAddress);
  console.log("Implementation:", implAddress);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
