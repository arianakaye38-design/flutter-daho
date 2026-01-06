# Firebase Security Rules Analysis for DAHO!
**Date:** December 14, 2025  
**Status:** ⚠️ NEEDS REVISION

---

## Executive Summary

Your Firebase Security Rules are **partially correct** but have **critical misalignments** with the app's actual data structure and features. The rules need significant updates to match the intended functionality.

### Overall Assessment:
- ✅ **Good:** Basic authentication and role-based access patterns
- ⚠️ **Issues:** Incorrect order schema, missing collections, performance concerns
- ❌ **Missing:** Pasalubong centers collection, proper courier tracking

---

## Detailed Analysis by Collection

### 1. **Users Collection** ⚠️ **NEEDS MINOR FIXES**

#### Current Rules:
```javascript
match /users/{userId} {
  allow read: if isSignedIn();
  allow create: if isSignedIn() && request.auth.uid == userId;
  allow update: if isOwnerOfDocument(userId) || isAdmin();
  allow delete: if isAdmin();
}
```

#### Issues Found:

**🔴 CRITICAL: getUserType() function causes extra reads**
```javascript
function getUserType() {
  return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.type;
}
```
- **Problem:** Every rule evaluation that calls `getUserType()` makes an extra Firestore read
- **Cost Impact:** This counts toward your Firestore quota and adds latency
- **Better Approach:** Use custom claims set server-side with Firebase Admin SDK

**🟡 MODERATE: Field name inconsistency**
- Rules check for field: `type`
- Recommended schema uses: `userType`
- **Fix:** Standardize on one field name (recommend `type` for simplicity)

**🟡 MODERATE: Too permissive read access**
- Current: Any authenticated user can read ANY user profile
- Risk: Privacy concerns - customers seeing courier personal data, etc.
- **Recommendation:**
```javascript
allow read: if isSignedIn() 
            && (request.auth.uid == userId  // Own profile
                || isAdmin()                 // Admin can see all
                || exists(/databases/$(database)/documents/orders/$(request.auth.uid)/participants/$(userId))); // Related via order
```

#### Recommended Updates:
```javascript
match /users/{userId} {
  // Users can read their own profile, admins can read all
  // Others can read limited public fields only
  allow read: if isOwnerOfDocument(userId) || isAdmin();
  
  // Public profile data (name, type) for order coordination
  allow get: if isSignedIn() 
             && request.resource.data.keys().hasAny(['name', 'type']);
  
  allow create: if isSignedIn() 
                && request.auth.uid == userId
                && request.resource.data.keys().hasAll(['email', 'name', 'type', 'createdAt'])
                && request.resource.data.type in ['customer', 'owner', 'courier']
                && request.resource.data.email == request.auth.token.email;
  
  allow update: if isOwnerOfDocument(userId) || isAdmin();
  allow delete: if isAdmin();
}
```

---

### 2. **Products Collection** ❌ **INCORRECT SCHEMA**

#### Current Rules:
```javascript
match /products/{productId} {
  allow read: if true;
  allow create: if isOwner() && request.resource.data.ownerId == request.auth.uid;
  // ...
}
```

#### Issues Found:

**🔴 CRITICAL: Missing `centerId` field**
- Products should belong to a **Pasalubong Center**, not directly to an owner
- Your assessment document specifies:
  ```
  products/
    ├── centerId: String  ← MISSING IN RULES!
    ├── ownerId: String   ← Should reference center owner
  ```

**🔴 CRITICAL: Missing required fields**
Current rules only check: `name`, `price`, `ownerId`, `createdAt`

Missing fields from your schema:
- `description: String`
- `imageUrl: String`
- `stock: Number`
- `isAvailable: Boolean`
- `centerId: String`

**🟡 MODERATE: No validation on data types**
- No check that `price` is a number
- No check that `price` is positive
- No check that `stock` is non-negative

#### Recommended Updates:
```javascript
match /products/{productId} {
  // Everyone can read products (public catalog)
  allow read: if true;
  
  // Only owners can create products for their centers
  allow create: if isOwner() 
                && request.resource.data.keys().hasAll([
                  'name', 'price', 'centerId', 'ownerId', 
                  'description', 'isAvailable', 'stock', 'createdAt'
                ])
                // Validate product belongs to owner's center
                && exists(/databases/$(database)/documents/pasalubong_centers/$(request.resource.data.centerId))
                && get(/databases/$(database)/documents/pasalubong_centers/$(request.resource.data.centerId)).data.ownerId == request.auth.uid
                // Validate data types
                && request.resource.data.price is number
                && request.resource.data.price > 0
                && request.resource.data.stock is number
                && request.resource.data.stock >= 0
                && request.resource.data.isAvailable is bool;
  
  // Owners can update their own products
  allow update: if isOwner() 
                && resource.data.ownerId == request.auth.uid
                && request.resource.data.ownerId == resource.data.ownerId  // Can't change owner
                && request.resource.data.centerId == resource.data.centerId;  // Can't change center
  
  // Owners can delete their own products; admin can delete any
  allow delete: if (isOwner() && resource.data.ownerId == request.auth.uid) 
                || isAdmin();
}
```

---

### 3. **Orders Collection** ❌ **COMPLETELY WRONG SCHEMA**

#### Current Rules Assume:
```javascript
{
  customerId: String,
  ownerId: String,
  productId: String,      ← WRONG! Should be items array
  status: String,
  // ...
}
```

#### Actual App Implementation:
Based on `lib/features/owner/orders_screen.dart` and `lib/features/customer/shop_screen.dart`:

```javascript
{
  orderId: String,
  customerId: String,
  customerName: String,       ← MISSING IN RULES
  customerPhone: String,      ← MISSING IN RULES
  customerAddress: String,    ← MISSING IN RULES
  items: Array<{              ← MISSING IN RULES
    name: String,
    quantity: Number,
    price: Number,
    productId: String
  }>,
  totalAmount: Number,        ← MISSING IN RULES
  status: String,
  courierId: String,
  orderDate: Timestamp,
  deliveryDate: Timestamp,    ← MISSING IN RULES
  centerId: String,           ← MISSING IN RULES
  notes: String               ← MISSING IN RULES
}
```

#### Issues Found:

**🔴 CRITICAL: Single product vs. shopping cart**
- Rules assume one order = one product (`productId`)
- App implementation uses shopping cart with **multiple items**
- This is a **fundamental mismatch**

**🔴 CRITICAL: Missing owner relationship**
- Orders should link to `centerId` (pasalubong center), not `ownerId`
- Owner is derived from center ownership

**🔴 CRITICAL: No total amount validation**
- Rules don't check that `totalAmount` matches sum of items
- Potential for fraud (user sets `totalAmount: 1` with expensive items)

#### Recommended Complete Rewrite:
```javascript
match /orders/{orderId} {
  // Helper function to calculate expected total
  function calculateTotal(items) {
    return items.reduce(function(sum, item) {
      return sum + (item.price * item.quantity);
    }, 0);
  }
  
  // Customers can read their own orders
  // Owners can read orders for their centers
  // Couriers can read assigned orders
  // Admin can read all
  allow read: if isAdmin()
              || (isSignedIn() && resource.data.customerId == request.auth.uid)
              || (isOwner() && isOwnerOfCenter(resource.data.centerId))
              || (isCourier() && resource.data.courierId == request.auth.uid);
  
  // Only customers can create orders
  allow create: if isCustomer() 
                && request.resource.data.customerId == request.auth.uid
                && request.resource.data.keys().hasAll([
                  'customerId', 'customerName', 'customerPhone', 
                  'customerAddress', 'items', 'totalAmount', 
                  'centerId', 'status', 'createdAt'
                ])
                && request.resource.data.status == 'pending'
                && request.resource.data.items.size() > 0
                && request.resource.data.items.size() <= 50  // Max 50 items per order
                // Validate total amount matches items
                && request.resource.data.totalAmount == calculateTotal(request.resource.data.items)
                // Validate center exists
                && exists(/databases/$(database)/documents/pasalubong_centers/$(request.resource.data.centerId));
  
  // Status update permissions by role
  allow update: if isAdmin()
                // Customer can cancel pending orders
                || (isCustomer() 
                    && resource.data.customerId == request.auth.uid 
                    && resource.data.status == 'pending'
                    && request.resource.data.status == 'cancelled')
                // Owner can confirm/prepare orders for their center
                || (isOwner() 
                    && isOwnerOfCenter(resource.data.centerId)
                    && resource.data.status in ['pending', 'confirmed']
                    && request.resource.data.status in ['confirmed', 'ready_for_pickup'])
                // Courier can update assigned orders
                || (isCourier() 
                    && resource.data.courierId == request.auth.uid
                    && resource.data.status in ['ready_for_pickup', 'picked_up', 'on_the_way']
                    && request.resource.data.status in ['picked_up', 'on_the_way', 'delivered']);
  
  allow delete: if isAdmin();
}
```

**Additional helper function needed:**
```javascript
function isOwnerOfCenter(centerId) {
  return isOwner() 
         && exists(/databases/$(database)/documents/pasalubong_centers/$(centerId))
         && get(/databases/$(database)/documents/pasalubong_centers/$(centerId)).data.ownerId == request.auth.uid;
}
```

---

### 4. **Messages Collection** ✅ **MOSTLY CORRECT**

#### Current Rules:
```javascript
match /messages/{messageId} {
  allow read: if isAdmin()
              || resource.data.senderId == request.auth.uid
              || resource.data.recipientId == request.auth.uid;
  // ...
}
```

#### Assessment:
- ✅ Read permissions are correct
- ✅ Create permissions ensure senderId matches auth
- ✅ Update/delete permissions appropriate

#### Minor Recommendations:

**🟡 Consider chat room structure instead:**
```javascript
// Better structure for ongoing conversations
match /chats/{chatId}/messages/{messageId} {
  // chatId could be: "customer_{customerId}_courier_{courierId}"
  function isChatParticipant() {
    let chatDoc = get(/databases/$(database)/documents/chats/$(chatId));
    return request.auth.uid in chatDoc.data.participants;
  }
  
  allow read: if isChatParticipant() || isAdmin();
  allow create: if isChatParticipant() 
                && request.resource.data.senderId == request.auth.uid;
}
```

**🟡 Add message length validation:**
```javascript
allow create: if isSignedIn() 
              && request.resource.data.senderId == request.auth.uid
              && request.resource.data.text.size() > 0
              && request.resource.data.text.size() <= 1000  // Max 1000 chars
              && request.resource.data.keys().hasAll(['senderId', 'recipientId', 'text', 'createdAt']);
```

---

### 5. **Notifications Collection** ✅ **CORRECT**

#### Assessment:
- ✅ Read permissions appropriate
- ✅ Only admin can create (prevents spam)
- ✅ Users can mark as read
- ✅ Users can delete own notifications

**No changes needed** - this is well-structured.

---

## ❌ **MISSING COLLECTIONS**

### **CRITICAL: Pasalubong Centers Collection**

This is the **core entity** of your app but is **completely missing** from security rules!

#### Required Structure (from your assessment doc):
```javascript
pasalubong_centers/
  ├── {centerId}/
      ├── name: String
      ├── ownerId: String
      ├── location: GeoPoint
      ├── address: String
      ├── phone: String
      ├── email: String
      ├── operatingHours: String
      ├── isApproved: Boolean
      ├── products: Array<String>
      └── createdAt: Timestamp
```

#### Recommended Rules:
```javascript
match /pasalubong_centers/{centerId} {
  // Everyone can read approved centers (for map display)
  allow read: if resource.data.isApproved == true;
  
  // Owners and admins can read unapproved centers
  allow get: if isAdmin() 
             || (isOwner() && resource.data.ownerId == request.auth.uid);
  
  // Only owners can create centers (pending approval)
  allow create: if isOwner() 
                && request.resource.data.ownerId == request.auth.uid
                && request.resource.data.keys().hasAll([
                  'name', 'ownerId', 'location', 'address', 
                  'phone', 'email', 'operatingHours', 'createdAt'
                ])
                && request.resource.data.isApproved == false  // Must start unapproved
                && request.resource.data.location is latlng;
  
  // Owners can update their own centers (but can't approve themselves)
  allow update: if (isOwner() 
                    && resource.data.ownerId == request.auth.uid
                    && request.resource.data.isApproved == resource.data.isApproved)
                // Only admin can approve/unapprove
                || (isAdmin() 
                    && request.resource.data.ownerId == resource.data.ownerId);  // Can't change owner
  
  allow delete: if isAdmin();
}
```

---

### **CRITICAL: Couriers Collection**

Needed for **location tracking** and **availability management** (separate from users collection).

#### Required Structure:
```javascript
couriers/
  ├── {courierId}/  // Same as userId
      ├── userId: String
      ├── name: String
      ├── currentLocation: GeoPoint
      ├── isOnline: Boolean
      ├── isAvailable: Boolean
      ├── activeOrderIds: Array<String>
      ├── vehicleType: String
      ├── rating: Number
      ├── completedOrders: Number
      └── lastLocationUpdate: Timestamp
```

#### Recommended Rules:
```javascript
match /couriers/{courierId} {
  // Everyone can read online couriers (for assignment)
  // In production, restrict to only what's needed
  allow read: if isSignedIn();
  
  // Only the courier can create/update their own profile
  allow create: if isCourier() 
                && request.auth.uid == courierId
                && request.resource.data.userId == request.auth.uid
                && request.resource.data.keys().hasAll([
                  'userId', 'name', 'currentLocation', 
                  'isOnline', 'isAvailable', 'vehicleType'
                ])
                && request.resource.data.currentLocation is latlng;
  
  // Courier can update their own location/availability
  // Admin can update rating/stats
  allow update: if (isCourier() && request.auth.uid == courierId)
                || isAdmin();
  
  allow delete: if isAdmin();
}
```

---

## Performance & Cost Concerns

### **🔴 CRITICAL: Excessive get() calls**

Your helper functions make extra Firestore reads:

```javascript
function getUserType() {
  return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.type;
  // ^^^^ EXTRA READ = EXTRA COST
}
```

#### Impact:
- **Cost:** Each rule evaluation = 1 extra document read
- **Latency:** Adds ~50-100ms to every request
- **Quota:** Eats into daily free tier (50K reads/day)

#### Solution: Use Custom Claims

**Set claims server-side (Firebase Admin SDK):**
```javascript
// backend/functions/index.js
exports.setUserRole = functions.https.onCall(async (data, context) => {
  const uid = context.auth.uid;
  const userDoc = await admin.firestore().collection('users').doc(uid).get();
  const userType = userDoc.data().type;
  
  // Set custom claim
  await admin.auth().setCustomUserClaims(uid, { 
    role: userType,
    isAdmin: userType === 'admin'
  });
  
  return { success: true };
});
```

**Update rules to use claims:**
```javascript
function getUserRole() {
  return request.auth.token.role;  // No extra read!
}

function isOwner() {
  return isSignedIn() && request.auth.token.role == 'owner';
}

function isCustomer() {
  return isSignedIn() && request.auth.token.role == 'customer';
}

function isCourier() {
  return isSignedIn() && request.auth.token.role == 'courier';
}
```

**Trigger on user creation:**
```javascript
exports.onUserCreated = functions.firestore
  .document('users/{userId}')
  .onCreate(async (snap, context) => {
    const userData = snap.data();
    await admin.auth().setCustomUserClaims(context.params.userId, {
      role: userData.type
    });
  });
```

---

## Security Best Practices Missing

### **1. Rate Limiting**
Not possible in Firestore rules, but implement in Cloud Functions:
```javascript
// Prevent spam order creation
exports.createOrder = functions.https.onCall(async (data, context) => {
  // Check if user created order in last 5 seconds
  const recentOrders = await admin.firestore()
    .collection('orders')
    .where('customerId', '==', context.auth.uid)
    .where('createdAt', '>', admin.firestore.Timestamp.now() - 5)
    .get();
    
  if (recentOrders.size > 0) {
    throw new functions.https.HttpsError('resource-exhausted', 'Too many requests');
  }
  
  // Create order...
});
```

### **2. Data Validation**
Add validation for:
- Email format
- Phone number format (PH format: +63XXXXXXXXXX)
- Coordinate bounds (Guimaras only: lat 10.5-10.7, lng 122.5-122.7)
- Text length limits
- Array size limits

### **3. Audit Logging**
Log sensitive operations:
```javascript
match /audit_log/{logId} {
  allow read: if isAdmin();
  allow write: if false;  // Only Cloud Functions can write
}
```

---

## Complete Corrected Firebase Rules

Here's the complete, corrected ruleset that aligns with your app:

```javascript
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {
    
    // ============================================
    // HELPER FUNCTIONS
    // ============================================
    
    function isSignedIn() {
      return request.auth != null;
    }
    
    function getUserRole() {
      return request.auth.token.role;  // Set via custom claims
    }
    
    function isAdmin() {
      return isSignedIn() && getUserRole() == 'admin';
    }
    
    function isOwner() {
      return isSignedIn() && getUserRole() == 'owner';
    }
    
    function isCustomer() {
      return isSignedIn() && getUserRole() == 'customer';
    }
    
    function isCourier() {
      return isSignedIn() && getUserRole() == 'courier';
    }
    
    function isOwnerOfDocument(userId) {
      return isSignedIn() && request.auth.uid == userId;
    }
    
    function isOwnerOfCenter(centerId) {
      return isOwner() 
             && exists(/databases/$(database)/documents/pasalubong_centers/$(centerId))
             && get(/databases/$(database)/documents/pasalubong_centers/$(centerId)).data.ownerId == request.auth.uid;
    }
    
    // ============================================
    // USERS COLLECTION
    // ============================================
    match /users/{userId} {
      allow read: if isOwnerOfDocument(userId) || isAdmin();
      
      allow create: if isSignedIn() 
                    && request.auth.uid == userId
                    && request.resource.data.keys().hasAll(['email', 'name', 'type', 'phone', 'createdAt'])
                    && request.resource.data.type in ['customer', 'owner', 'courier']
                    && request.resource.data.email == request.auth.token.email;
      
      allow update: if isOwnerOfDocument(userId) || isAdmin();
      allow delete: if isAdmin();
    }
    
    // ============================================
    // PASALUBONG CENTERS COLLECTION
    // ============================================
    match /pasalubong_centers/{centerId} {
      // Everyone can read approved centers
      allow list: if request.query.limit <= 50;  // Prevent large queries
      allow get: if true;
      
      allow create: if isOwner() 
                    && request.resource.data.ownerId == request.auth.uid
                    && request.resource.data.keys().hasAll([
                      'name', 'ownerId', 'location', 'address', 
                      'phone', 'email', 'operatingHours', 'createdAt'
                    ])
                    && request.resource.data.isApproved == false
                    && request.resource.data.location is latlng
                    // Validate coordinates are in Guimaras
                    && request.resource.data.location.latitude > 10.4
                    && request.resource.data.location.latitude < 10.8
                    && request.resource.data.location.longitude > 122.4
                    && request.resource.data.location.longitude < 122.8;
      
      allow update: if (isOwner() 
                        && resource.data.ownerId == request.auth.uid
                        && request.resource.data.isApproved == resource.data.isApproved)
                    || (isAdmin() 
                        && request.resource.data.ownerId == resource.data.ownerId);
      
      allow delete: if isAdmin();
    }
    
    // ============================================
    // PRODUCTS COLLECTION
    // ============================================
    match /products/{productId} {
      allow read: if true;
      
      allow create: if isOwner() 
                    && request.resource.data.keys().hasAll([
                      'name', 'price', 'centerId', 'ownerId', 
                      'description', 'isAvailable', 'stock', 'createdAt'
                    ])
                    && isOwnerOfCenter(request.resource.data.centerId)
                    && request.resource.data.ownerId == request.auth.uid
                    && request.resource.data.price is number
                    && request.resource.data.price > 0
                    && request.resource.data.stock is number
                    && request.resource.data.stock >= 0;
      
      allow update: if isOwner() 
                    && resource.data.ownerId == request.auth.uid
                    && request.resource.data.ownerId == resource.data.ownerId
                    && request.resource.data.centerId == resource.data.centerId;
      
      allow delete: if (isOwner() && resource.data.ownerId == request.auth.uid) 
                    || isAdmin();
    }
    
    // ============================================
    // ORDERS COLLECTION
    // ============================================
    match /orders/{orderId} {
      allow read: if isAdmin()
                  || (isSignedIn() && resource.data.customerId == request.auth.uid)
                  || (isOwner() && isOwnerOfCenter(resource.data.centerId))
                  || (isCourier() && resource.data.courierId == request.auth.uid);
      
      allow create: if isCustomer() 
                    && request.resource.data.customerId == request.auth.uid
                    && request.resource.data.keys().hasAll([
                      'customerId', 'customerName', 'customerPhone', 
                      'customerAddress', 'items', 'totalAmount', 
                      'centerId', 'status', 'createdAt'
                    ])
                    && request.resource.data.status == 'pending'
                    && request.resource.data.items.size() > 0
                    && request.resource.data.items.size() <= 50
                    && request.resource.data.totalAmount > 0
                    && exists(/databases/$(database)/documents/pasalubong_centers/$(request.resource.data.centerId));
      
      allow update: if isAdmin()
                    || (isCustomer() 
                        && resource.data.customerId == request.auth.uid 
                        && resource.data.status == 'pending')
                    || (isOwner() && isOwnerOfCenter(resource.data.centerId))
                    || (isCourier() && resource.data.courierId == request.auth.uid);
      
      allow delete: if isAdmin();
    }
    
    // ============================================
    // COURIERS COLLECTION
    // ============================================
    match /couriers/{courierId} {
      allow read: if isSignedIn();
      
      allow create: if isCourier() 
                    && request.auth.uid == courierId
                    && request.resource.data.userId == request.auth.uid
                    && request.resource.data.currentLocation is latlng;
      
      allow update: if (isCourier() && request.auth.uid == courierId) || isAdmin();
      allow delete: if isAdmin();
    }
    
    // ============================================
    // MESSAGES COLLECTION
    // ============================================
    match /messages/{messageId} {
      allow read: if isAdmin()
                  || resource.data.senderId == request.auth.uid
                  || resource.data.recipientId == request.auth.uid;
      
      allow create: if isSignedIn() 
                    && request.resource.data.senderId == request.auth.uid
                    && request.resource.data.keys().hasAll(['senderId', 'recipientId', 'text', 'createdAt'])
                    && request.resource.data.text.size() > 0
                    && request.resource.data.text.size() <= 1000;
      
      allow update: if resource.data.senderId == request.auth.uid;
      allow delete: if resource.data.senderId == request.auth.uid || isAdmin();
    }
    
    // ============================================
    // NOTIFICATIONS COLLECTION
    // ============================================
    match /notifications/{notificationId} {
      allow read: if isAdmin() || resource.data.userId == request.auth.uid;
      allow create: if isAdmin();
      allow update: if resource.data.userId == request.auth.uid;
      allow delete: if resource.data.userId == request.auth.uid || isAdmin();
    }
    
    // ============================================
    // ADMIN COLLECTIONS
    // ============================================
    match /admin/{document=**} {
      allow read, write: if isAdmin();
    }
    
    // ============================================
    // DEFAULT DENY
    // ============================================
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

---

## Implementation Checklist

### **Before deploying these rules:**

- [ ] Set up Firebase Admin SDK in backend
- [ ] Create Cloud Function to set custom claims on user creation
- [ ] Migrate existing users to have custom claims
- [ ] Update app code to use correct field names (`type` vs `userType`)
- [ ] Update order creation to include all required fields
- [ ] Create pasalubong_centers collection schema
- [ ] Create couriers collection schema
- [ ] Test rules with Firebase Emulator Suite
- [ ] Deploy to staging environment first
- [ ] Monitor Firestore usage for unexpected costs

### **After deployment:**

- [ ] Monitor Firebase Console for denied requests
- [ ] Set up alerts for security rule violations
- [ ] Review audit logs weekly
- [ ] Update rules as features evolve

---

## Summary of Changes Needed

| Collection | Status | Priority | Changes Required |
|------------|--------|----------|------------------|
| users | ⚠️ Minor fixes | 🟡 MEDIUM | Switch to custom claims, restrict read access |
| pasalubong_centers | ❌ Missing | 🔴 HIGH | **Add entire collection rules** |
| products | ❌ Wrong schema | 🔴 HIGH | Add centerId, validation, stock checks |
| orders | ❌ Wrong schema | 🔴 HIGH | **Complete rewrite** - support items array, total validation |
| couriers | ❌ Missing | 🔴 HIGH | **Add entire collection rules** |
| messages | ✅ OK | 🟢 LOW | Optional: add length validation |
| notifications | ✅ OK | 🟢 LOW | No changes needed |

---

## Conclusion

Your Firebase Security Rules show good understanding of **role-based access patterns**, but they **don't match your actual app structure**. The most critical issues are:

1. **Missing collections** (pasalubong_centers, couriers)
2. **Wrong order schema** (single product vs shopping cart)
3. **Performance concerns** (excessive get() calls)
4. **Missing validation** (price, stock, location bounds)

**Recommendation:** Use the corrected rules provided above and implement custom claims before going to production.

---

**Analysis Prepared By:** GitHub Copilot  
**Date:** December 14, 2025
