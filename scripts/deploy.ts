import { network } from "hardhat";
const { ethers } = await network.connect();

async function main() {
    console.log("🚀 Desplegando el contrato Counter...");

    // Esto busca el archivo Counter.sol en tu carpeta contracts
    const counter = await ethers.deployContract("SimpleStorage");

    // Esperamos a que la red confirme el despliegue
    await counter.waitForDeployment();

    const address = await counter.getAddress();
    console.log(`✅ Contrato desplegado con éxito!`);
    console.log(`📍 Dirección del contrato: ${address}`);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});