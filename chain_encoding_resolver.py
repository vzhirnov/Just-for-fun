import base64
import json
import xml.etree.ElementTree as elementTree


class ChainEncodingResolver:
    def __init__(self):
        self.res = []

    def clean_res(self):
        self.res = []

    def is_xml(self, value):
        try:
            elementTree.fromstring(value)
        except Exception:
            return False
        return True

    def is_json(self, value):
        try:
            if json.loads(value):
                if isinstance(eval(value), dict):
                    return True
        except Exception:
            return False
        return False

    def is_base64(self, value):
        try:
            if isinstance(value, str):
                sb_bytes = bytes(value, 'ascii')
            elif isinstance(value, bytes):
                sb_bytes = value
            else:
                raise ValueError("Argument must be string or bytes")
            return base64.b64encode(base64.b64decode(sb_bytes)) == sb_bytes
        except Exception:
            return False

    def get_encoding_chain(self, container):
        self.clean_res()
        self.determine_encoding_chain(container)
        return self.res

    def determine_encoding_chain(self, container):
        if container == '':
            return
        if self.is_xml(container):
            self.res.append('xml')
            self.res.append(container)
        elif self.is_json(container):
            self.res.append('json')
            self.res.append(container)
        elif self.is_base64(container):
            try:
                base64_bytes = container.encode()
                message_bytes = base64.b64decode(base64_bytes)
                message = message_bytes.decode()
                self.res.append('base64')
                self.determine_encoding_chain(message)
            except Exception:
                self.res.append(container)
        else:
            self.res.append(container)


cer = ChainEncodingResolver()
print(cer.get_encoding_chain(1))
print(cer.get_encoding_chain("just simple string"))
print(cer.get_encoding_chain("Imp1c3Qgc2ltcGxlIHN0cmluZyI="))
print(cer.get_encoding_chain("SW1wMWMzUWdjMmx0Y0d4bElITjBjbWx1WnlJPQ=="))
print(cer.get_encoding_chain('ODEyOTM4MTkyODE5MjgzNzkxODgxMjkzODE5MjgxOTI4Mzc5MTg4MTI5MzgxOTI4MTkyODM3OTE4ODEyOTM4MTkyODE5MjgzNzkxODgxMjkzODE5MjgxOTI4Mzc5MTg='))

print(cer.get_encoding_chain("<one>1</one>"))
print(cer.get_encoding_chain("PG9uZT4xPC9vbmU+"))
print(cer.get_encoding_chain("UEc5dVpUNHhQQzl2Ym1VKw=="))

print(cer.get_encoding_chain('eyJhIjogW119'))


