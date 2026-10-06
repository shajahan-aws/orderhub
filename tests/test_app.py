import pytest
from app.app import app

@pytest.fixture
def client():
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client

def test_index(client):
    res = client.get('/')
    assert res.status_code == 200
    assert res.json['message'] == "OrderHub API"

def test_health(client):
    res = client.get('/health')
    assert res.status_code == 200
    assert res.json['status'] == "UP"

def test_orders(client):
    res = client.get('/orders')
    assert res.status_code == 200
    assert len(res.json['orders']) > 0

def test_version(client):
    res = client.get('/version')
    assert res.status_code == 200
    assert "version" in res.json