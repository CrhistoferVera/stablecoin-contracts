Proyecto de ejemplo con Hardhat 3 Beta (mocha y ethers)

Este proyecto es un ejemplo de cómo usar Hardhat 3 Beta para desarrollar contratos inteligentes en Ethereum, haciendo tests con mocha y conectándose a la blockchain usando la librería ethers.

Si quieren aprender más sobre Hardhat 3 Beta, pueden visitar la guía de inicio
. También pueden dar feedback en el grupo de Telegram Hardhat 3 Beta
 o crear un reporte de problemas en GitHub
.

Resumen del proyecto

Este ejemplo incluye:

Un archivo de configuración básico de Hardhat.

Tests unitarios de Solidity (los contratos se prueban solos).

Tests de integración en TypeScript usando mocha y ethers.js (simula cómo se usaría el contrato en una app real).

Ejemplos de cómo conectarse a distintas redes, incluyendo una simulación local de la red principal de Optimism (OP Mainnet).

Cómo usarlo:
Ejecutar tests

Para correr todos los tests del proyecto, usar:

npx hardhat test


También se pueden correr solo los tests de Solidity o solo los de mocha:

npx hardhat test solidity   # solo tests de Solidity
npx hardhat test mocha      # solo tests de integración con Mocha

Hacer un deploy (subir el contrato a la red)

El proyecto incluye un ejemplo de módulo llamado Ignition que sirve para desplegar el contrato.

Deploy en una red local (simulada)
npx hardhat ignition deploy ignition/modules/Counter.ts


Esto sube el contrato a una blockchain local que Hardhat simula. Es rápido y no gasta dinero.

Deploy en Sepolia (testnet real)

Para desplegar en Sepolia necesitas una cuenta con fondos de prueba.

En la configuración de Hardhat hay una variable llamada SEPOLIA_PRIVATE_KEY.

Puedes asignarle la clave privada de tu cuenta de prueba. Por ejemplo, usando hardhat-keystore:

npx hardhat keystore set SEPOLIA_PRIVATE_KEY


Luego, haces el deploy en Sepolia:

npx hardhat ignition deploy --network sepolia ignition/modules/Counter.ts


Esto subirá tu contrato a la testnet Sepolia y podrás interactuar con él desde cualquier wallet o aplicación que soporte Ethereum.