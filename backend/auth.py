import os
import time
import jwt
from typing import Optional
from fastapi import HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import bcrypt as _bcrypt

JWT_SECRET = os.getenv("JWT_SECRET", "change_me")
JWT_EXPIRE_MINUTES = int(os.getenv("JWT_EXPIRE_MINUTES", "2880"))

security = HTTPBearer()

# Demo user store: username=andrew, password=password123
_pwd = "password123".encode("utf-8")
USERS = {
    "andrew": _bcrypt.hashpw(_pwd, _bcrypt.gensalt()).decode("utf-8")
}

def create_token(sub: str) -> str:
    now = int(time.time())
    exp = now + JWT_EXPIRE_MINUTES * 60
    payload = {"sub": sub, "iat": now, "exp": exp}
    return jwt.encode(payload, JWT_SECRET, algorithm="HS256")

def verify_password(username: str, password: str) -> bool:
    hashed = USERS.get(username)
    if not hashed:
        return False
    return _bcrypt.checkpw(password.encode("utf-8"), hashed.encode("utf-8"))

def require_auth(creds: HTTPAuthorizationCredentials = Depends(security)) -> str:
    token = creds.credentials
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=["HS256"])
        return payload["sub"]
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid or expired token")
