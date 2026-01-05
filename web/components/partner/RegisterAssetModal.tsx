"use client";

import { useState } from "react";
import { RegisterMode, RegisterVehicleForm } from "./forms/RegisterVehicleForm";
import { XMarkIcon } from "@heroicons/react/24/outline";
import { ASSET_REGISTRIES, AssetType } from "~~/config/assetTypes";

interface RegisterAssetModalProps {
  isOpen: boolean;
  onClose: () => void;
  initialMode: RegisterMode;
}

export const RegisterAssetModal = ({ isOpen, onClose, initialMode }: RegisterAssetModalProps) => {
  // Filter for active registries
  const activeRegistries = Object.entries(ASSET_REGISTRIES).filter(([, config]) => config.active);
  const singleActiveType = activeRegistries.length === 1 ? (activeRegistries[0][0] as AssetType) : null;

  // Auto-select if only one type is active, otherwise start null
  const [selectedType, setSelectedType] = useState<AssetType | null>(singleActiveType);

  if (!isOpen) return null;

  const handleBack = () => {
    // If only one type, back means close
    if (singleActiveType) {
      onClose();
    } else {
      setSelectedType(null);
    }
  };

  return (
    <div className="modal modal-open">
      <div className="modal-backdrop bg-black/50 backdrop-blur-sm" onClick={onClose} />
      <div className="modal-box relative max-w-2xl">
        {/* Close Button */}
        <button className="btn btn-sm btn-circle btn-ghost absolute right-3 top-3" onClick={onClose}>
          <XMarkIcon className="h-5 w-5" />
        </button>

        {!selectedType ? (
          <>
            {/* Header */}
            <div className="mb-6">
              <h3 className="font-bold text-xl">Register New Asset</h3>
              <p className="text-sm opacity-60 mt-1">Select the type of asset you want to register</p>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
              {activeRegistries.map(([key, config]) => (
                <button
                  key={key}
                  className="btn h-auto py-8 flex flex-col gap-2 hover:border-primary"
                  onClick={() => setSelectedType(key as AssetType)}
                >
                  <span className="text-4xl">{config.icon}</span>
                  <span className="text-xl font-bold">{config.name}</span>
                  <span className="text-xs font-normal opacity-70 px-4">{config.description}</span>
                </button>
              ))}
            </div>
            <div className="modal-action">
              <button type="button" className="btn btn-ghost" onClick={onClose}>
                Cancel
              </button>
            </div>
          </>
        ) : (
          /* Polymorphic Form Rendering */
          <>
            {selectedType === AssetType.VEHICLE && (
              <RegisterVehicleForm onClose={onClose} initialMode={initialMode} onBack={handleBack} />
            )}
            {selectedType === AssetType.REAL_ESTATE && (
              <div className="text-center py-10">
                <h3 className="text-lg font-bold">Coming Soon</h3>
                <p>Real Estate registration is not yet supported.</p>
                <button className="btn btn-ghost mt-4" onClick={handleBack}>
                  Go Back
                </button>
              </div>
            )}
          </>
        )}
      </div>
    </div>
  );
};
