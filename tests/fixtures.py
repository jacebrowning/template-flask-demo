# pylint: disable=redefined-outer-name

import pytest

from demo_project.settings import get_config
from demo_project.factory import create_app


@pytest.fixture
def app():
    return create_app(get_config('test'))


@pytest.fixture
def client(app):
    return app.test_client()
