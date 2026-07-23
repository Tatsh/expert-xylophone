#include "neTexture.h"

namespace ne {

/** @ghidraAddress 0x31af4 */
void ReleaseRefCountedObject(C_TEXTURE *pObject) {
    // The reference count is decremented before the null check, matching the binary; callers pass a
    // non-null object.
    int nCount = pObject->ReleaseRef();
    if (pObject != nullptr && nCount == 0) {
        // The binary tail-calls the object's deleting destructor through its vtable slot; delete
        // dispatches the same virtual destructor.
        delete pObject;
    }
}

} // namespace ne
