import pytest
from urllib import request
from zipfile import ZipFile


states = {}


@pytest.fixture(scope='session')
def r128_test_data(tmp_path_factory):
    '''Download and extract the test WAV files.'''

    # The latest data can be found here:
    # https://tech.ebu.ch/publications/ebu_loudness_test_set
    url = 'https://tech.ebu.ch/files/live/sites/tech/files/shared/testmaterial/ebu-loudness-test-setv05.zip' # noqa
    z = tmp_path_factory.getbasetemp() / 'ebu-loudness-test-setv05.zip'

    data = request.urlopen(url)
    with open(z, 'wb') as fp:
        fp.write(data.read())

    with ZipFile(z, 'r') as zp:
        zp.extractall(tmp_path_factory.getbasetemp())

    return tmp_path_factory.getbasetemp()


@pytest.fixture(scope='session')
def r128_states():
    return states
