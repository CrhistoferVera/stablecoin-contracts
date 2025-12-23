# HUNBOLI Stablecoin - Spec (borrador)

## Roles
- DEFAULT_ADMIN_ROLE: ...
- MINTER_ROLE: ...
- PAUSER_ROLE: ...
- COMPLIANCE_ROLE (si aplica): ...

## Reglas clave
- Decimals: 6
- Mint/Burn: ...
- Pause: bloquea transfer/transferFrom (y define approve)
- Blacklist: bloquea from/to (y define si afecta approve)

## Eventos esperados
- Transfer
- Paused/Unpaused
- BlacklistUpdated (o similar)
