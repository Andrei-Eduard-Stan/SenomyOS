.pragma library

function validate(lockMinutes,displayOffMinutes,lidAction) {
    const lockValue=Number(lockMinutes);
    const displayValue=Number(displayOffMinutes);
    if(!Number.isInteger(lockValue) || lockValue < 1 || lockValue > 60)
        throw new Error("Lock timeout must use whole minutes between 1 and 60.");
    if(!Number.isInteger(displayValue) || displayValue < 2 || displayValue > 120 || displayValue <= lockValue)
        throw new Error("Display-off timeout must be a whole minute later than the lock timeout.");
    if(["lock","none"].indexOf(String(lidAction)) < 0)
        throw new Error("Lid action must be lock or none.");
    return {lockSeconds:lockValue*60,displayOffSeconds:displayValue*60,lidAction:String(lidAction)};
}

function parseResponse(text) {
    const value=JSON.parse(text);
    if(!value.ok)
        throw new Error(value.error || "Session policy preferences are unavailable.");
    const lockSeconds=Number(value.lockSeconds);
    const displayOffSeconds=Number(value.displayOffSeconds);
    if(!Number.isInteger(lockSeconds) || !Number.isInteger(displayOffSeconds))
        throw new Error("Session policy status is unavailable.");
    return {
        available:!!value.available,
        configured:!!value.configured,
        lockSeconds:lockSeconds,
        displayOffSeconds:displayOffSeconds,
        suspendEnabled:!!value.suspendEnabled,
        lockBeforeSleep:!!value.lockBeforeSleep,
        lidAvailable:!!value.lidAvailable,
        lidAction:["lock","none"].indexOf(String(value.lidAction)) >= 0 ? String(value.lidAction) : "lock",
        activationRequired:!!value.activationRequired
    };
}
