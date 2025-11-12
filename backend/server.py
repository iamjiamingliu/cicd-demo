import os

from flask import Flask, jsonify, request, Response
from flask_cors import CORS

# Init
app = Flask(__name__)

# Don't worry about this! Just some required security stuff; look into CORS and cross-site-scripting (XSS) if you're interested!
CORS(app)

# API endpoint!
@app.get("/api/your-mom")
def home():
    return Response("Error: file too big!", status=413)

# Place endpoints in this space; they define functions/routes the app will save and look out for when requests come in
# It'll parse and match accordingly; otherwise, it'll reject with a 404 error
# Also, you may see HTTP requests with an OPTIONS method; this just a "preflight" check done automatically to prevent against XSS (as mentioned above)

database = []

@app.get("/get-test")
def get_test():
    return "Hello"

@app.post("/post-test")
def post_test():
    body = request.get_data(as_text=True)
    
    if body == "mail":
        return "good"

    return "bad"

@app.put("/item")
def put_test():
    body = request.get_data(as_text=True)
    database.append(body)
    
    return "All good"

@app.get("/item/<name>")
def get_item(name: str):
    try:
        ind = database.index(name)  
        return f"Index is: {ind}"
    except ValueError:
        pass
    
    return "Couldn't find"

@app.delete("/kill/<killed>")
def delete_test(killed: str):
    try:
        database.remove(killed)
        return "Killed it"
    except ValueError:
        pass
    
    return "Couldn't find anything"

if __name__ == "__main__":
    # Render injects PORT; default to 8080 locally
    port = int(os.environ.get("PORT", 8080))
    app.run(host="0.0.0.0", port=port)

