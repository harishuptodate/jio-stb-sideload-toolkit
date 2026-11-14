package com.gathin.tvhome;

import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.drawable.Drawable;
import android.text.style.ImageSpan;

import androidx.annotation.NonNull;

public class CenteredImageSpan extends ImageSpan {
    public CenteredImageSpan(@NonNull Drawable drawable) {
        super(drawable);
    }

    @Override
    public int getSize(@NonNull Paint paint, CharSequence text,
                       int start, int end, Paint.FontMetricsInt fm) {
        Drawable d = getDrawable();
        return d.getBounds().right;
    }

    @Override
    public void draw(@NonNull Canvas canvas, CharSequence text,
                     int start, int end, float x,
                     int top, int y, int bottom, @NonNull Paint paint) {
        Drawable d = getDrawable();
        canvas.save();
        Paint.FontMetricsInt fm = paint.getFontMetricsInt();
        int transY = y + (fm.descent + fm.ascent) / 2 - d.getBounds().height() / 2;
        canvas.translate(x, transY);
        d.draw(canvas);
        canvas.restore();
    }
}
