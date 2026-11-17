import os
import uuid

import django

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "ebook.settings")
django.setup()

from django.test import Client
from django.contrib.auth import get_user_model
from rest_framework_simplejwt.tokens import RefreshToken

from accounts.models import Shop

User = get_user_model()
client = Client(SERVER_NAME="localhost")
passed = []
failed = []


def check(name, ok, detail=""):
    if ok:
        passed.append(name)
    else:
        failed.append(name)
    print(("PASS  " if ok else "FAIL  ") + name + (("  | " + str(detail)) if detail else ""))


def bearer(u):
    return {"HTTP_AUTHORIZATION": "Bearer " + str(RefreshToken.for_user(u).access_token)}


suffix = uuid.uuid4().hex[:8]
shop, _ = Shop.objects.get_or_create(
    name="SmokeTest Shop " + suffix,
    defaults={"owner_name": "Smoke Owner", "phone": "9999999999", "email": "smoke-owner-" + suffix + "@example.com"},
)
owner, _ = User.objects.get_or_create(
    email="smoke-owner-" + suffix + "@example.com",
    defaults={"name": "Smoke Owner", "phone": "9999999999", "role": "owner", "shop": shop},
)
owner.set_password("Smoke@12345")
owner.save()
auth = bearer(owner)

EXPORTS = [
    ("transactions", "excel", "spreadsheetml", b"PK"),
    ("transactions", "csv", "text/csv", b"\xef\xbb\xbf"),
    ("transactions", "pdf", "application/pdf", b"%PDF"),
    ("report", "excel", "spreadsheetml", b"PK"),
    ("report", "csv", "text/csv", b"\xef\xbb\xbf"),
    ("report", "pdf", "application/pdf", b"%PDF"),
]
for endpoint, fmt, ct, magic in EXPORTS:
    r = client.get("/api/reports/export/%s/?format=%s" % (endpoint, fmt), **auth)
    body = r.content
    ok = (
        r.status_code == 200
        and ct in (r.get("Content-Type") or "")
        and len(body) > 30
        and body[: len(magic)] == magic
    )
    check("export %s %s" % (endpoint, fmt), ok, "status=%s ct=%s len=%s" % (r.status_code, r.get("Content-Type"), len(body)))

r = client.get("/api/reports/export/dashboard/", **auth)
check(
    "export dashboard pdf",
    r.status_code == 200 and (r.get("Content-Type") or "") == "application/pdf" and r.content[:4] == b"%PDF",
    "status=%s len=%s" % (r.status_code, len(r.content)),
)
r = client.get("/api/reports/export/dashboard/?format=excel", **auth)
check(
    "export dashboard excel",
    r.status_code == 200 and "spreadsheetml" in (r.get("Content-Type") or "") and r.content[:2] == b"PK",
    "status=%s len=%s" % (r.status_code, len(r.content)),
)
r = client.get("/api/reports/export/cc-bills/", **auth)
check(
    "export cc-bills excel",
    r.status_code == 200 and "spreadsheetml" in (r.get("Content-Type") or "") and r.content[:2] == b"PK",
    "status=%s len=%s" % (r.status_code, len(r.content)),
)

cat_name = "SmokeCat_" + suffix
r = client.post(
    "/api/transactions/categories/create/",
    data={"name": cat_name, "category_type": "cc_bill"},
    content_type="application/json",
    **auth,
)
check("category create category_type=cc_bill", r.status_code in (200, 201), "status=%s body=%s" % (r.status_code, r.content[:200]))
cat_id = None
try:
    cat_id = r.json().get("id")
except Exception:
    pass

r = client.get("/api/transactions/categories/?type=cc_bill", **auth)
names = []
if r.status_code == 200:
    try:
        data = r.json()
        items = data.get("results", data) if isinstance(data, dict) else data
        names = [i.get("name") for i in items]
    except Exception:
        pass
check("category list type=cc_bill contains created", r.status_code == 200 and cat_name in names, "status=%s n=%s" % (r.status_code, len(names)))

r = client.get("/api/transactions/categories/?type=service", **auth)
cc_names = []
if r.status_code == 200:
    try:
        data = r.json()
        items = data.get("results", data) if isinstance(data, dict) else data
        cc_names = [i.get("name") for i in items]
    except Exception:
        pass
check("category list type=service excludes cc_bill", r.status_code == 200 and cat_name not in cc_names, "status=%s" % r.status_code)

if cat_id:
    r = client.delete("/api/transactions/categories/%s/" % cat_id, **auth)
    check("category delete", r.status_code in (200, 204), "status=%s" % r.status_code)

cp_email = "smoke-chpw-" + suffix + "@example.com"
cp_user = User.objects.create_user(
    email=cp_email, name="Chpw User", phone="9888777666", shop=shop, password="OldPass@12345", role="staff"
)
cp_auth = bearer(cp_user)
r = client.post(
    "/api/auth/change-password/",
    data={"old_password": "WrongOld@123", "new_password": "NewPass@12345"},
    content_type="application/json",
    **cp_auth,
)
err_body = r.content.decode("utf-8", "ignore")
check("change-password wrong old rejected with message", r.status_code == 400 and "old" in err_body.lower(), "status=%s body=%s" % (r.status_code, err_body[:200]))
r = client.post(
    "/api/auth/change-password/",
    data={"old_password": "OldPass@12345", "new_password": "NewPass@12345"},
    content_type="application/json",
    **cp_auth,
)
check("change-password success", r.status_code == 200, "status=%s body=%s" % (r.status_code, r.content[:200]))
r = client.post(
    "/api/auth/login/",
    data={"email": cp_email, "password": "NewPass@12345"},
    content_type="application/json",
)
check("login with new password", r.status_code == 200, "status=%s body=%s" % (r.status_code, r.content[:200]))
r = client.post(
    "/api/auth/login/",
    data={"email": cp_email, "password": "OldPass@12345"},
    content_type="application/json",
)
body = r.content.decode("utf-8", "ignore")
check("login wrong password returns error message", r.status_code == 401 and "error" in body.lower(), "status=%s body=%s" % (r.status_code, body[:200]))

reg_email = "smoke-reg-" + suffix + "@example.com"
r = client.post(
    "/api/auth/register/",
    data={
        "email": reg_email,
        "name": "Reg User",
        "phone": "9111222333",
        "password": "Register@123",
        "shop_name": "Reg Shop " + suffix,
        "shop_phone": "9111222333",
        "shop_address": "1 Test St",
        "shop_city": "Hyderabad",
        "shop_state": "TS",
        "shop_pincode": "500001",
    },
    content_type="application/json",
)
check("register with password creates account", r.status_code == 201, "status=%s body=%s" % (r.status_code, r.content[:200]))
r = client.post(
    "/api/auth/register/",
    data={
        "email": reg_email,
        "name": "Reg User",
        "phone": "9111222333",
        "password": "Register@123",
        "shop_name": "Reg Shop 2",
        "shop_phone": "9111222333",
    },
    content_type="application/json",
)
body = r.content.decode("utf-8", "ignore")
check("register duplicate email returns message", r.status_code in (400, 409) and "exist" in body.lower(), "status=%s body=%s" % (r.status_code, body[:200]))

try:
    User.objects.filter(email=reg_email).delete()
    Shop.objects.filter(name="Reg Shop " + suffix).delete()
except Exception:
    pass
cp_user.delete()
owner.delete()
shop.delete()

print("")
print("PASSED: %d  FAILED: %d" % (len(passed), len(failed)))
if failed:
    print("FAILED CHECKS:")
    for f in failed:
        print("  - " + f)
    raise SystemExit(1)
