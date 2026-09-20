package net.osmand.plus.inapp;

import android.app.Activity;
import android.content.Context;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import net.osmand.plus.OsmandApplication;
import net.osmand.plus.inapp.InAppPurchases.InAppPurchase.PurchaseOrigin;
import java.lang.ref.WeakReference;

public class InAppPurchaseHelperImpl extends InAppPurchaseHelper {
    public InAppPurchaseHelperImpl(OsmandApplication ctx) { super(ctx); }
    public boolean isPurchasedLocalFullVersion() { return false; }
    public boolean isPurchasedLocalDeepContours() { return false; }
    public boolean isSubscribedToLocalLiveUpdates() { return false; }
    public boolean isSubscribedToLocalOsmAndPro() { return false; }
    public boolean isSubscribedToLocalMaps() { return false; }
    public void isInAppPurchaseSupported(
        @NonNull final Activity activity,
        @Nullable final InAppPurchaseInitCallback callback
    ) { }
    public String getPlatform() { return PLATFORM_GOOGLE; }
    protected void execImpl(
        @NonNull final InAppPurchaseTaskType taskType,
        @NonNull final InAppCommand runnable
    ) { }
    public void purchaseFullVersion(@NonNull final Activity activity) { }
    public void purchaseDepthContours(@NonNull final Activity activity) { }
    public void purchaseContourLines(@NonNull Activity activity)
        throws UnsupportedOperationException { }
    public void manageSubscription(
        @NonNull Context ctx, @Nullable String sku, @Nullable PurchaseOrigin origin
    ) { }
    protected InAppCommand getPurchaseSubscriptionCommand(
        final WeakReference<Activity> activity,
        final String sku,
        final String userInfo
    ) { return null; }
    protected InAppCommand getRequestInventoryCommand(boolean userRequested) {
        return null;
    }
    protected boolean isBillingManagerExists() { return false; }
    protected boolean isLocalBillingUnavailable() { return true; }
    protected boolean isBillingUnavailable() { return true; }
    protected void destroyBillingManager() { }
}

