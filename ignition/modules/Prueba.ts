import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("PruebaModule", (m) => {
  // 1. Desplegar el contrato Prueba
  const prueba = m.contract("Prueba");

  // 2. Llamar a setNumber después del deploy
  m.call(prueba, "setNumber", [42n]);

  // 3. Retornar el contrato
  return { prueba };
});
