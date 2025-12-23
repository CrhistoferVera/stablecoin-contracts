import { network } from "hardhat";
const { ethers } = await network.connect();
async function main() {
    const counterAddress = "0x5FbDB2315678afecb367f032d93F642f64180aa3";

    console.log("🔗 Conectando al contrato en:", counterAddress);
    const counter = await ethers.getContractAt("Counter", counterAddress);

    // Leer valor actual
    const valorActual = await counter.x();
    console.log("\n📊 Valor actual del contador:", valorActual.toString());

    // Incrementar en 1
    console.log("\n⬆️  Incrementando en 1...");
    const tx1 = await counter.inc();
    await tx1.wait();
    console.log("✅ Transacción confirmada");

    const nuevoValor = await counter.x();
    console.log("📊 Nuevo valor:", nuevoValor.toString());

    // Incrementar por 100
    console.log("\n⬆️  Incrementando por 100...");
    const tx2 = await counter.incBy(100);
    await tx2.wait();
    console.log("✅ Transacción confirmada");

    const valorFinal = await counter.x();
    console.log("📊 Valor final:", valorFinal.toString());
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });