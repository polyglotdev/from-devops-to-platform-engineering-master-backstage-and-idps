from datetime import datetime
import socket
from fastapi import FastAPI

app = FastAPI()


@app.get('/api/v1/hello')
def read_root():
  return {'message': 'Hello, World!'}


@app.get('/api/v1/healthz')
def healthz():
  return {'status': 'ok'}


@app.get('/api/v1/details')
def details():
  # return the details of the system
  return {
    'hostname': socket.gethostname(),
    'ip': socket.gethostbyname(socket.gethostname()),
  }


@app.get('/api/v1/getdate')
def getdate():
  # return date DD-MM-YYYY
  return {'date': datetime.now().strftime('%d-%m-%Y')}
