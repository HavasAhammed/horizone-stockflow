import mongoose, { Schema, Document } from 'mongoose';

export interface ISaleDoc extends Document {
  id: string;
  saleDate: Date;
  customerId: string;
  consumerNumber: string;
  customerName?: string;
  panelWattage: number;
  type: string;
  quantity: number;
  serialNumbers: string[];
  unitSellingPrice: number;
  totalSellingAmount: number;
  notes?: string;
  createdAt: Date;
  updatedAt: Date;
}

const saleSchema = new Schema<ISaleDoc>(
  {
    id: { type: String, required: true, unique: true, index: true },
    saleDate: { type: Date, required: true },
    customerId: { type: String, required: true, index: true },
    consumerNumber: { type: String, required: true, index: true },
    customerName: { type: String },
    panelWattage: { type: Number, required: true },
    type: {
      type: String,
      enum: ['DCR', 'Non DCR'],
      default: 'DCR',
      index: true,
    },
    quantity: { type: Number, required: true },
    serialNumbers: { type: [String], required: true },
    unitSellingPrice: { type: Number, required: true },
    totalSellingAmount: { type: Number, required: true },
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

export const SaleModel = mongoose.model<ISaleDoc>('Sale', saleSchema);
