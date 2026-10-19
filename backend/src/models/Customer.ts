import mongoose, { Schema, Document } from 'mongoose';

export interface ICustomerDoc extends Document {
  id: string;
  consumerNumber: string;
  phone: string;
  name?: string;
  address?: string;
  createdAt: Date;
  updatedAt: Date;
}

const customerSchema = new Schema<ICustomerDoc>(
  {
    id: { type: String, required: true, unique: true, index: true },
    consumerNumber: { type: String, required: true, unique: true, index: true },
    phone: { type: String, required: true },
    name: { type: String },
    address: { type: String },
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

export const CustomerModel = mongoose.model<ICustomerDoc>('Customer', customerSchema);
