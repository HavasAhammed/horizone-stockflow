import mongoose, { Schema, Document } from 'mongoose';

export interface IPurchaseDoc extends Document {
  id: string;
  purchaseDate: Date;
  supplierName?: string;
  batchNumber: string;
  wattage: number;
  quantity: number;
  serialNumbers: string[];
  unitPurchasePrice: number;
  totalPurchaseAmount: number;
  notes?: string;
  createdAt: Date;
  updatedAt: Date;
}

const purchaseSchema = new Schema<IPurchaseDoc>(
  {
    id: { type: String, required: true, unique: true, index: true },
    purchaseDate: { type: Date, required: true },
    supplierName: { type: String },
    batchNumber: { type: String, required: true, index: true },
    wattage: { type: Number, required: true },
    quantity: { type: Number, required: true },
    serialNumbers: { type: [String], required: true },
    unitPurchasePrice: { type: Number, required: true },
    totalPurchaseAmount: { type: Number, required: true },
    notes: { type: String },
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

export const PurchaseModel = mongoose.model<IPurchaseDoc>('Purchase', purchaseSchema);
