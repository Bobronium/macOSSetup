from collections.abc import Sequence, Mapping
from datetime import datetime
from typing import Any


ComplexInnerTypes = Sequence[Any] | Mapping[str, Any] | bytes
PlistValue = Mapping[str, Any] | Sequence[Any] | bool | int | float | str | datetime | bytes
PlistList = Sequence[PlistValue]
PlistRoot = Mapping[str, PlistValue]
