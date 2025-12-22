import { network } from "hardhat";
const { ethers } = await network.connect();
async function main() {
    const simpleStorageAddress = "0x5FbDB2315678afecb367f032d93F642f64180aa3";
    console.log("🔗 Conectando al contrato en:", simpleStorageAddress);

    const simpleStorage = await ethers.getContractAt("SimpleStorage", simpleStorageAddress);

    // Leer valor actual
    const valorActual = await simpleStorage.retrieve();
    console.log("\n📊 Valor actual del contador:", valorActual.toString());

    // Almacenar un nuevo valor
    console.log("\n💾 Almacenando el valor 42...");
    const tx1 = await simpleStorage.store(42);
    await tx1.wait();
    console.log("✅ Transacción confirmada");

    const nuevoValor = await simpleStorage.retrieve();
    console.log("📊 Nuevo valor:", nuevoValor.toString());


    // Almacenar una persona
    console.log("\n💾 Almacenando la persona 'Alice' con edad 30...")
    const tx2 = await simpleStorage.addPerson("Alice", 30);
    await tx2.wait();
    console.log("✅ Transacción confirmada");
    const persona = await simpleStorage.people(0);
    console.log("📊 Persona almacenada:", persona.name, "con edad", persona.favoriteNumber.toString());
}
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });