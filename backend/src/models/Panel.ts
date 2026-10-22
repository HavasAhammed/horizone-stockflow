import mongoose, { Schema, Document } from 'mongoose';

export interface IPanelDoc extends Document {
  id: string;
  serialNumber: string;
  batchNumber: string;
  wattage: number;
  type: string;
  purchaseId: string;
  purchasePrice: number;
  status: 'available' | 'sold';
  saleId?: string | null;
  createdAt: Date;
  updatedAt: Date;
}

const panelSchema = new Schema<IPanelDoc>(
  {
    id: { type: String, required: true, unique: true },
    serialNumber: { type: String, required: true, unique: true, index: true },
    batchNumber: { type: String, required: true, index: true },
    wattage: { type: Number, required: true, index: true },
    type: {
      type: String,
      enum: ['DCR', 'Non DCR'],
      default: 'DCR',
      index: true,
    },
    purchaseId: { type: String, required: true, index: true },
    purchasePrice: { type: Number, required: true },
    status: {
      type: String,
      enum: ['available', 'sold'],
      default: 'available',
      index: true,
    },
    saleId: { type: String, default: null, index: true },
  },
  {
    timestamps: true,
    toJSON: {
      transform: (_doc, ret: any) => {
        delete ret._id;
        delete ret.__v;
        return ret;
      },
    },
  }
);

export const PanelModel = mongoose.model<IPanelDoc>('Panel', panelSchema);
